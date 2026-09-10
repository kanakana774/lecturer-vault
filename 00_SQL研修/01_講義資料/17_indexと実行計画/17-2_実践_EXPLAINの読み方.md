# インデックスと実行計画（実践編）

**この章の範囲**：インデックスを作り、`EXPLAIN` で効果を確かめる。物理構造とスキャン方式は [[17-1_導入_物理構造とスキャン方式|17-1]]。

> - PostgreSQL 17。掲載している実行計画・ページ数・実行時間は**すべて実測値**です。手元で再現できます
> - テーブルは [[17_indexと実行計画で使用するテーブル|17_indexと実行計画で使用するテーブル]]（`customers` 10万件 = 1,235ページ / `orders` 100万件 = 7,255ページ）
> - **この2つのページ数が全編を通じた基準値です。`Buffers` がこの数字と一致したら全件走査。**

[参考：fujitsu パフォーマンスチューニング9つの技 ～「探し」について～](https://global.fujitsu/ja-jp/local/software/postgres/tuningrule9-search)

---

## 1. インデックスの作り方

### 1-1. 基本形

```sql
CREATE INDEX idx_customers_city ON customers (city);
ANALYZE customers;                  -- 作ったら必ず統計情報を更新する
```

命名は自由ですが、`idx_テーブル名_列名` にしておくと後から読めます。何も指定しなければ **B-Tree** が作られます。

### 1-2. 4つの型を使い分ける

| 種類 | 何をするもの | こんな時に使う |
| :--- | :--- | :--- |
| **単一列** | 1つの列に作る基本形 | `WHERE city = 'City_123'` |
| **複合** | 複数列をセットで作る。**列の順番が超重要** | `WHERE customer_id = 1 AND order_date >= '...'` |
| **カバリング** | 取得したい列もインデックスに含める | `Index Only Scan` を狙いたい |
| **関数** | 列を加工した結果に作る | `WHERE LOWER(email) = '...'` |

```sql
-- ① 単一列
CREATE INDEX idx_customers_city ON customers (city);

-- ② 複合（customer_id で絞り、その中で order_date で絞るクエリに有効）
CREATE INDEX idx_orders_cust_date ON orders (customer_id, order_date);

-- ③ カバリング（customer_id をキーにし、order_date もインデックスに含める）
CREATE INDEX idx_orders_cust_cover ON orders (customer_id) INCLUDE (order_date);

-- ④ 関数（WHERE句で使う式と「まったく同じ式」で作る）
CREATE INDEX idx_customers_email_lower ON customers (LOWER(email));
```

*   **③ `INCLUDE` の列は検索条件には使えませんが、取得する値として使える**ので、テーブル本体を読まずに済みます（`Index Only Scan`）。
*   **② `(A, B)` の順で作ると、`WHERE A = ?` や `WHERE A = ? AND B = ?` では効きますが、`WHERE B = ?` だけでは効きません**（→ §5-④）。

![[17-2_複合インデックスの並び方.excalidraw]]

**辿り方は 17-1 §5-1 の図とまったく同じです。** 違うのは**比べる対象**で、**`(苗字, 名前)` をセットにした1つの値**として大小を比べています（`(鈴木, 一郎)` は `(佐藤, 花子)` より大きく、`(田中, 太郎)` より小さい）。

だから**まず「苗字」でソートされ、同じ苗字の中で「名前」でソートされている**形になります。複合キーは、インデックスを2本持っているのとは違います。**名前だけを指定しても、その名前は木のあちこちに散っている**ので辿る手がかりになりません。これが「`WHERE B = ?` だけでは効かない」の中身です。

---

## 2. EXPLAIN の基本

### 2-1. `EXPLAIN` と `EXPLAIN ANALYZE`

```sql
-- ① 予測だけを見る（クエリは実行されない）
EXPLAIN SELECT * FROM customers WHERE city = 'City_123';

-- ② 実際に実行して、実測値も見る
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers WHERE city = 'City_123';
```

*   **`ANALYZE`**: 実際に実行して実測値（`actual time`、実際の行数）を出す。
*   **`BUFFERS`**: **読んだページ数**を出す。ここが本質なので、**常に付けてください。**

> ⚠️ **`ANALYZE` は「実際にクエリを実行する」オプションです。**
> `SELECT` なら安全ですが、`UPDATE` / `DELETE` / `INSERT` に付けると**本当にデータが変わります**。更新系で実行計画を見たいときは、必ずトランザクションで囲んで戻してください。
> ```sql
> BEGIN;
> EXPLAIN (ANALYZE, BUFFERS) DELETE FROM orders WHERE order_id = 1;
> ROLLBACK;
> ```

### 2-2. 出力1行の構造

```text
ノード名  (cost=起動コスト..総コスト rows=推定行数 width=推定行幅)
          (actual time=起動時間..総時間 rows=実際の行数 loops=ループ回数)
  付加情報（Index Cond, Filter, Sort Key など）
  Buffers: shared hit=N read=N
```

上のカッコが**プランナの予測**、下のカッコが**実際の結果**です。**この2つを見比べるのが読み方の基本です。**

---

## 3. 実行計画の読みどころ

### 3-1. 読む順番：上下ではなく「字下げの深さ」

**基本ルール：字下げが深いノードほど先に実行される。** 子ノードが行を作り、親ノードがそれを受け取ります。

**同じ深さに兄弟ノードが並ぶときは、上が「外側」・下が「内側」です。** ただし**どちらが先に動くかは結合方式で変わります**。

*   `Nested Loop`：上（外側）が1行返すたびに下（内側）を実行する → **上が先**
*   `Hash Join`：下（内側）を全件読んでハッシュテーブルを作り終えてから、上（外側）を流し込む → **下が先**

```text
Hash Join                            ← ③ 最後に突き合わせ
  ->  Seq Scan on orders             ← ② ①の完成後に流し込む（外側）
  ->  Hash                           ← ① まずここを作り切る（内側）
        ->  Seq Scan on customers
```

そのため「下から上へ読む」という説明は、枝分かれのない単純な計画でしか成り立ちません。**上下ではなく「字下げの深さ」で捉えてください。**

### 3-2. ノードの種類

| 分類     | ノード                                                    | 内容                                                        |
| :----- | :----------------------------------------------------- | :-------------------------------------------------------- |
| スキャン   | **Seq Scan**                                           | 全件走査                                                      |
|        | **Index Scan**                                         | インデックスから住所を得て本体を狙い撃ち                                      |
|        | **Index Only Scan**                                    | 本体を見ずインデックス内で完結                                           |
|        | **Bitmap Index Scan**<br>＋ Bitmap Heap Scan            | 住所を地図にしてページ順にまとめ読み                                        |
|        | **Index Scan Backward**                                | インデックスを逆順に辿る（`ORDER BY ... DESC`）                         |
| 結合     | **Nested Loop**                                        | 外側1行ごとに内側をスキャン                                            |
|        | **Hash Join**                                          | ハッシュテーブルを作って突き合わせ                                         |
|        | **Merge Join**                                         | 双方をソートして突き合わせ                                             |
| ソート・集約 | **Sort**                                               | 並べ替え。`ORDER BY` だけでなく `GROUP BY` や `Merge Join` の前処理でも現れる |
|        | **Aggregate** / **HashAggregate** / **GroupAggregate** | 集計（`COUNT` `SUM` `GROUP BY`）                              |
|        | **Limit**                                              | 必要な行数が揃った時点で打ち切る                                          |
| その他    | Hash / BitmapOr / BitmapAnd / Materialize              | 上位ノードの下請けとして現れる                                           |

**`Sort` は「消せるかもしれないノード」です。** インデックスは既にソート済みなので、うまく使えば `Sort` そのものが不要になります（→ §5 のコラム「これは効きます」）。また大量データのソートはメモリを食い、**溢れるとディスクを使う**（`Buffers` に `temp` が出る）ため、`Sort` を見つけたら一度見直す価値があります。

#### 結合方式（Join Methods）の使い分け

3方式の違いは、**「総当たり（外側の行数 × 内側の行数）をどう避けるか」**の違いだけです。

| 方式              | 総当たりをどう避けるか                        | 選ばれるのはこんな時                                |
| :-------------- | :--------------------------------- | :---------------------------------------- |
| **Nested Loop** | **引く** — 外側1行ごとに、内側をインデックスで一発で引く    | 外側が少数 ＋ **内側の結合キーにindexがある**              |
| **Hash Join**   | **計算する** — 探すのをやめて、置き場所をハッシュ値から計算する | **大量データ同士**（indexは不要）。ただし**等価結合（`=`）専用**  |
| **Merge Join**  | **並走する** — 双方をソートして、先頭から一度だけ突き合わせる  | 両側が**すでにソート済み**（index順に読める）               |

**3方式に絶対的な優劣はありません。** 「Hash が速い」ではなく、**条件が揃っている方式が選ばれる**だけです。とくに `Nested Loop` は、**内側の結合キーにインデックスがあるかどうか**で性質が正反対になります（無いと「外側の行数 × 内側の全ページ」の総当たりになる → ケース2）。

> ⚠️ **どれが選ばれるかは、データ量・インデックスの有無・`work_mem` の設定で簡単に入れ替わります。** 「この結合はいつも Hash」と覚えず、**その場で `EXPLAIN` して確かめてください。**

### 3-3. 予測を読む（cost / rows / width）

`cost=0.00..15.25` の形式です。

*   左（0.00）：**最初の1行**を返すまでのコスト
*   右（15.25）：**全行**を返すまでの推定合計コスト
*   単位は「**シーケンシャルに**ページ1枚を読む時間」を1とした相対値（`seq_page_cost = 1.0`）。秒でもミリ秒でもありません。

**cost は「比べるための指標」です。** 絶対値そのものに意味はありません。**同じクエリに対する別の計画と比べる**ために使います。プランナも、複数の計画のこの数字を比べて一番小さいものを選んでいるだけです。

| パラメータ | 既定値 | 意味 | 適正値 |
| :--- | :--- | :--- | :--- |
| `seq_page_cost` | 1.0 | ページを**順番に**1枚読む | そのまま |
| `random_page_cost` | **4.0** | ページを**ランダムに**1枚読む | HDD：**4.0**（既定）<br>SSD：**1.1〜2** |

※ **これらの設定を変えるのは管理者の領域**です。ここでは「そういう前提で計算されている」ことだけ押さえてください。

*   **`rows`**：プランナが統計情報から予測した出力行数。
*   **`width`**：1行あたりの推定バイト数。`SELECT *` だと全列の合計になります。

### 3-4. 実測を読む（actual time / rows / loops）

`ANALYZE` を付けたときだけ出ます。

*   **`actual time=0.016..10.227`**：左が最初の1行まで、右がそのノードの処理完了までの**実測ミリ秒**。子ノードの時間を含んだ累積値です。
*   **`rows`**：そのノードが**実際に出力した**行数。**§3-3 の推定 `rows` と見比べます。** 10倍以上ズレていたら統計情報を疑います（`ANALYZE テーブル名;`）。
*   **`loops`**：そのノードが**呼び出された回数**。Nested Loop の内側などで2以上になります。

⚠️ **`loops` が2以上のとき、`actual time` と `rows` は「1ループあたりの平均値」です。** 総量は自分で掛け算する必要があります。表示上は小さな数字でも、実際はそこが処理の大半を占めていることがあります。**ボトルネックの見落としは、たいていここで起きます。**

```text
->  Index Only Scan using idx_orders_cust_cover on orders o
          (actual time=0.002..0.002 rows=10 loops=1000)      ← ★1,000回呼ばれている
      Buffers: shared hit=3034

総出力行数 = 10行 × 1,000ループ = 10,000行     ← 親の rows と一致する
```

この計画では内側だけで **3,034ページ**（全体3,253の約93%）を読んでいて、**クエリの重さはほぼ全部が内側のループにあります。**

> 💡 **`Buffers` と `actual time` は「そのノードと、その下にある全ノードの合計」です。**
>
> | ノード | `Buffers` |
> | :--- | ---: |
> | `Bitmap Index Scan`（子） | 10 |
> | `Bitmap Heap Scan`（親） | **219** ← 子の10を**含む**。本体から読んだのは209 |
> | `Nested Loop`（一番上） | **3,253** ← 219 ＋ 3,034 |
>
> **「このノード単体で何ページ読んだか」を知りたいときは、子のぶんを引いてください。**

### 3-5. Buffers（I/Oの実態）

`Buffers: shared hit=1235 read=2` の形式です。

*   **`shared hit`**: 共有バッファ（メモリ）で見つかったページ数 → 速い
*   **`shared read`**: ディスクから読んだページ数 → 遅い
*   **`temp read` / `written`**: `work_mem` に収まらず一時ファイルを使った → **危険信号**（→ 演習 問題8）

**`hit + read` の合計＝そのノードが読んだページ数**です。これを減らすことがチューニングのゴールです。

> 📌 **この研修環境では `shared read` はほぼ0になります。データが共有バッファに全部収まる**からです（`shared_buffers` 128MB に対し `customers` 9.9MB ＋ `orders` 57MB ＝ 約67MB）。**この資料の実測値がほぼ `shared hit` なのは正常**なので、**「`hit + read` の合計＝読んだページ数」の大小で比較してください。**
> 本番環境のように**テーブルがメモリに収まらない規模**になると、この数字がそのまま `shared read`（実際のディスク読み）に変わり、実行時間に直結します。

### 3-6. `Index Cond` と `Filter` の違い（重要）

同じ「絞り込み」でも、実行計画では2箇所に分かれて表示されます。**ここの区別が読めると、インデックスの改善点が一発で分かります。**

*   **`Index Cond`** … **インデックスで絞り込めた**条件。速い。
*   **`Filter`** … インデックスでは絞れず、**行を取ってきた後にCPUで捨てた**条件。無駄。

> **チューニングの定石**：**`Filter` に出ている列を複合インデックスに足して、`Index Cond` へ昇格させる。** 特に `Rows Removed by Filter` が大きい場合に効きます。

> [!example]- 手を動かして確かめる（`Filter` を `Index Cond` へ昇格させる）
> `orders(customer_id)` と `orders(order_date)` を**別々の単一列インデックス**として持っている状態で、両方を条件にします。
>
> ```sql
> EXPLAIN SELECT * FROM orders WHERE customer_id = 1234 AND order_date >= '2025-01-01';
> ```
>
> ```text
> Bitmap Heap Scan on orders  (cost=4.50..43.54 rows=5 width=25)
>   Filter: (order_date >= '2025-01-01 00:00:00'::timestamp without time zone)   ← ⚠️ 後で捨てている
>   ->  Bitmap Index Scan on idx_orders_customer_id  (cost=0.00..4.50 rows=10 width=0)
>         Index Cond: (customer_id = 1234)                                        ← これだけで絞った
> ```
>
> `customer_id` で10件に絞ってから、`order_date` は**取ってきた後にフィルタ**しています。では複合インデックスにすると──
>
> ```sql
> CREATE INDEX idx_orders_cust_date ON orders (customer_id, order_date);
> ```
>
> ```text
> Bitmap Heap Scan on orders  (cost=4.48..24.16 rows=5 width=25)
>   ->  Bitmap Index Scan on idx_orders_cust_date  (cost=0.00..4.47 rows=5 width=0)
>         Index Cond: ((customer_id = 1234) AND (order_date >= '2025-01-01'::timestamp))
> ```
>
> **`Filter` が消えて、両方の条件が `Index Cond` に昇格しました。** コストも 43.54 → 24.16 に下がっています。

---

## 4. ケーススタディ（すべて実測）

### ケース1：インデックスがない → 張る

10万件の顧客から、特定の都市の顧客（200件）を検索します。

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers WHERE city = 'City_123';
```

**❌ インデックスなし**

```text
Seq Scan on customers  (cost=0.00..2485.00 rows=200 width=69)
                       (actual time=0.016..10.227 rows=200 loops=1)
  Filter: (city = 'City_123'::text)
  Rows Removed by Filter: 99800
  Buffers: shared hit=1235
Execution Time: 10.247 ms
```

*   `Buffers: shared hit=1235` は `customers` の**総ページ数と完全一致**。全ページ読んだ証拠です。
*   `Rows Removed by Filter: 99800` — 200件のために99,800件を読んで捨てています。

**⭕ インデックスを張った後**

```sql
CREATE INDEX idx_customers_city ON customers (city);
ANALYZE customers;
```

```text
Bitmap Heap Scan on customers  (cost=5.83..533.52 rows=199 width=69)
                               (actual time=0.061..0.182 rows=200 loops=1)
  Recheck Cond: (city = 'City_123'::text)
  Heap Blocks: exact=186
  Buffers: shared hit=200 read=2
  ->  Bitmap Index Scan on idx_customers_city  (actual time=0.042..0.042 rows=200 loops=1)
        Index Cond: (city = 'City_123'::text)
Execution Time: 0.196 ms
```

**1,235ページ → 202ページ。10.2ms → 0.20ms（約52倍）。**

`Index Scan` ではなく `Bitmap Heap Scan` が選ばれたのは、200件が別々のページに散っているからです（17-1 §6-4 で `ctid` を数えて確認した通り）。

### ケース2：【罠】外部キーにインデックスがない

> **PostgreSQLは、主キーとUNIQUE制約にはインデックスを自動作成しますが、外部キーには作りません。**

実務で最も多いインデックス貼り忘れのパターンです。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.name, o.order_date
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_id = 1234;
```

**❌ インデックスなし**

```text
Nested Loop  (actual time=0.654..8.222 rows=10 loops=1)
  Buffers: shared hit=7258
  ->  Index Scan using customers_pkey on customers c  (actual time=0.007..0.012 rows=1 loops=1)
        Index Cond: (customer_id = 1234)
        Buffers: shared hit=3
  ->  Seq Scan on orders o  (actual time=0.063..48.469 rows=10 loops=1)
        Filter: (customer_id = 1234)
        Rows Removed by Filter: 199990          ← ⚠️ ここがボトルネック
        Buffers: shared hit=7255
Execution Time: 48.526 ms
```

*   `customers` 側は**3ページ**で1行に絞れているのに、結合相手の `orders` で**全7,255ページ**を読んでいます。全体の99.96%が無駄読みです。
*   **読み方のコツ：「字下げが深い方（内側）が `Seq Scan` になっていないか」。** これが最も効く着眼点です。

**⭕ `orders(customer_id)` にインデックスを張った後**

```text
Nested Loop  (actual time=0.392..0.414 rows=10 loops=1)
  Buffers: shared hit=13 read=3
  ->  Index Scan using customers_pkey on customers c  (rows=1 loops=1)
        Buffers: shared hit=3
  ->  Bitmap Heap Scan on orders o  (actual time=0.149..0.161 rows=10 loops=1)
        Recheck Cond: (customer_id = 1234)
        Heap Blocks: exact=10
        Buffers: shared hit=10 read=3
Execution Time: 0.196 ms
```

**7,258ページ → 16ページ。48.5ms → 0.20ms（約247倍）。** `Rows Removed by Filter` は消えました。

### ケース3：【最強】テーブル本体を見ない

```sql
CREATE INDEX idx_orders_cust_cover ON orders (customer_id) INCLUDE (order_date);
```

```sql
VACUUM ANALYZE orders;   -- ★重要：Visibility Map を更新する。この行だけを単独で実行すること
```

> ⚠️ **`VACUUM` は他のSQLとまとめて実行できません。** 複数のSQLを一度に流すとPostgreSQLが1つのトランザクションとして扱うため、`ERROR: VACUUM cannot run inside a transaction block` になります。**その行だけを選択して実行**してください。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, order_date FROM orders WHERE customer_id = 500;
```

```text
Index Only Scan using idx_orders_cust_cover on orders  (cost=0.42..4.60 rows=10 width=12)
                                                      (actual time=0.094..0.095 rows=10 loops=1)
  Index Cond: (customer_id = 500)
  Heap Fetches: 0
  Buffers: shared hit=1 read=3
Execution Time: 0.127 ms
```

**わずか4ページ**、そして `Heap Fetches: 0`。テーブル本体を一度も読んでいません。

⚠️ **`VACUUM` を打たないとVisibility Mapが更新されず、`Heap Fetches` が増えて効果が消えます**（→ 17-1 §6-5）。

**`SELECT *` に変えると Index Only ではなくなります。**

```text
Bitmap Heap Scan on orders  (actual time=0.014..0.025 rows=10 loops=1)
  Recheck Cond: (customer_id = 500)
  Heap Blocks: exact=10
  Buffers: shared hit=13
```

インデックスに入っていない `order_id` と `status` を取るために、結局ヒープを読んでいます（4ページ → 13ページ）。**「SELECTする列を絞る」ことがそのままI/O削減になる**という分かりやすい例です。

### ケース4：【重要】同じインデックスでも、値によって計画が変わる

`orders.status` にインデックスを張ります。分布は Completed 90% / Shipped 8% / Pending 2% です。

```sql
CREATE INDEX idx_orders_status ON orders (status);
ANALYZE orders;
```

**`status = 'Pending'`（2% = 2万件）**

```text
Index Scan using idx_orders_status on orders  (actual time=0.595..2.905 rows=20000 loops=1)
  Index Cond: ((status)::text = 'Pending'::text)
  Buffers: shared hit=128 read=20
Execution Time: 3.501 ms
```

**`status = 'Completed'`（90% = 90万件）**

```text
Seq Scan on orders  (actual time=0.008..115.875 rows=900000 loops=1)
  Filter: ((status)::text = 'Completed'::text)
  Buffers: shared hit=7255
Execution Time: 144.680 ms
```

**同じテーブル、同じインデックス、同じSQLの形。違うのは検索する値だけ。** それでも一方は148ページ、もう一方は7,255ページ（全件走査）になりました。

プランナは統計情報から「この値は何件くらいヒットするか」を知っています。90%もヒットするなら、インデックス経由で飛び回るより全部読んだ方が安いと**正しく**判断しています。

### まとめ：チューニングの優先順位

1.  **読んでいるページ数（`Buffers` の hit + read）が多いノードを探す**
    *   `pg_class.relpages` と一致していたら全件走査です。
2.  **`Rows Removed by Filter` を見る**
    *   大量に捨てている場所は、インデックスで絞り込めていない証拠です。
3.  **`Filter` に出ている条件を `Index Cond` に昇格できないか考える**（→ §3-6）
4.  **結合の「内側（字下げが深い方）」が `Seq Scan` になっていないか見る**
    *   `loops` が多いとき、ここでのSeq Scanは致命的です。
5.  **推定 `rows` と実測 `rows` が大きくズレていないか見る**
    *   ズレていれば `ANALYZE`。それでも直らなければ、サーバー側のコスト設定を疑う段階です（自分では直せないので、先輩やDBA担当に相談してください）。

---

## 5. インデックスが効かない落とし穴

インデックスがあっても、**SQLの書き方**で使えなくなることがあります。

### ① 列を加工している（最頻出）

インデックスは「**加工前の生の値**」で並んでいます。列を関数や計算式に入れると、並び順が使えなくなります。

*   ❌ **効かない**
    ```sql
    SELECT * FROM orders WHERE DATE(order_date) = '2024-06-01';
    ```
    ```text
    Seq Scan on orders  (actual time=16.600..78.893 rows=1440 loops=1)
      Buffers: shared hit=7255                      ← 全ページ読んでいる
    Execution Time: 78.937 ms
    ```
*   ⭕ **改善：列はそのままにして、条件側を範囲に書き換える**
    ```sql
    SELECT * FROM orders
    WHERE order_date >= '2024-06-01' AND order_date < '2024-06-02';
    ```
    ```text
    Index Scan using idx_orders_order_date on orders  (actual time=0.197..0.373 rows=1440 loops=1)
      Buffers: shared hit=11 read=6                  ← 17ページ
    Execution Time: 0.413 ms
    ```

**7,255ページ → 17ページ。78.9ms → 0.41ms（約191倍）。同じ結果を返すSQLです。**

同じ理由で、次もすべて効きません。**「列を触らない」**と覚えてください。

| ❌ 効かない書き方                                       | ⭕ 直し方                                           |
| :---------------------------------------------- | :---------------------------------------------- |
| `WHERE order_date + interval '30 days' < now()` | `WHERE order_date < now() - interval '30 days'` |
| `WHERE UPPER(name) = 'ALICE'`                   | 関数インデックス                                        |
| `WHERE customer_id::text = '1234'`              | `WHERE customer_id = 1234`                      |

**キャストについて補足。** `customer_id::text = '1234'` は列側にキャストが付くので効きません。

```text
Seq Scan on customers   Filter: ((customer_id)::text = '1234'::text)
```

一方 `WHERE customer_id = '1234'` は**問題なく効きます**。リテラル側が数値として解決されるためです。

```text
Index Scan using customers_pkey on customers   Index Cond: (customer_id = 1234)
```

**どうしても加工した形で検索したい場合は、関数インデックスを作ります。**

```sql
-- ❌ Seq Scan（1,235ページ / 16.5ms）
SELECT * FROM customers WHERE LOWER(email) = 'user5555@example.com';

CREATE INDEX idx_customers_email_lower ON customers (LOWER(email));

-- ⭕ Index Scan（4ページ / 0.12ms）── 約137倍
```

### ② 否定形で書いている

「〜ではない」は、インデックスでは絞り込めません。索引を引いて「該当しないもの全部」を集めるのは、全部見るのと同じことだからです。

*   ❌ **効かない**
    ```sql
    SELECT * FROM orders WHERE status <> 'Completed';
    -- SELECT * FROM orders WHERE status NOT IN ('Completed');  -- これも同じ
    ```
    ```text
    Seq Scan on orders  (cost=0.00..19755.00 rows=102033 width=25)
      Filter: ((status)::text <> 'Completed'::text)
    ```
*   ⭕ **改善：欲しい値を列挙する（肯定形にする）**
    ```sql
    SELECT * FROM orders WHERE status IN ('Shipped', 'Pending');
    ```
    ```text
    Index Scan using idx_orders_status on orders  (cost=0.42..2921.91 rows=102033 width=25)
      Index Cond: ((status)::text = ANY ('{Shipped,Pending}'::text[]))
    ```

**推定行数はどちらも 102,033 行、つまり結果は同じです。** 書き方を変えただけで `Seq Scan` が `Index Scan` になり、コストが 19,755 → 2,921 に下がりました。`status` のように取りうる値が少ない列では、この書き換えが有効です。

### ③ LIKE の前方一致になっていない

*   ⭕ **効く可能性がある**：`LIKE 'ABC%'`（前方一致）
*   ❌ **効かない**：`LIKE '%ABC'` `LIKE '%ABC%'`（後方・部分一致）
*   **理由**：辞書で「あ」から始まる単語はすぐ引けますが、「あ」で終わる単語は最初から最後まで読むしかありません。

**なぜ前方一致だけ効くのか。** PostgreSQL は `LIKE 'ABC%'` を、内部で**範囲検索に読み替えている**からです。

```text
Index Cond: ((name)::text >= 'ABC'::text) AND ((name)::text < 'ABD'::text)
```

「ABC以上、ABD未満」──これはソート済みのB-Treeがいちばん得意な形です（17-1 §5-4）。逆に `'%ABC'` は開始位置が決まらないので、この読み替えができません。

> ⚠️ **`_` も「任意の1文字」のワイルドカードです。** だから `LIKE 'Customer_5555%'` の前置きは `Customer` までしか取れず、実測で全件走査（1,235ページ）になります。`LIKE 'Customer\_5555%'` とエスケープすれば本来の前方一致に戻り、**5ページ**で済みます。
> **ユーザー入力をそのまま `LIKE` に渡す作りだと `_` や `%` が紛れ込みます。** 検索機能を作るときはエスケープ処理を入れてください。

> ⚠️ **本番環境で「前方一致なのにインデックスが効かない」ことがあります。**
> 日本語向けの設定（照合順序が `ja_JP.UTF-8` など）だと、上の範囲検索への読み替えが成立しないためです。その場合は `CREATE INDEX ... (name text_pattern_ops);` と指定して作り直すと効くようになります。
> **今は「そういう落とし穴がある」とだけ覚えておけば十分です。** 研修環境は `C` ロケールなので、そのまま効きます。

### ④ 複合インデックスの順番を無視している

`(A, B)` の順で作った場合、**A を指定せず B だけで検索しても効きません**（§1-2 の構造図の通り）。

*   ⭕ **効く**：`WHERE A = 10` / `WHERE A = 10 AND B = 20`
*   ❌ **効かない**：`WHERE B = 20`

`orders (customer_id, order_date)` の複合インデックスだけがある状態で `order_date` 単独で検索すると、実際に全件走査になります。

```text
Seq Scan on orders  (cost=0.00..19755.00 rows=100 width=25)
```

**設計時のコツ**：`WHERE` で**必ず指定される列を左に**置きます。

### ⑤ OR の片方にインデックスがない

`OR` は、**片方でもインデックスが使えないと全体が全件走査になります。**

*   ⭕ **両方にインデックスあり** → `BitmapOr` で両方のインデックスを使う
    ```text
    Bitmap Heap Scan on customers
      ->  BitmapOr
            ->  Bitmap Index Scan on idx_customers_city      Index Cond: (city = 'City_5')
            ->  Bitmap Index Scan on customers_pkey          Index Cond: (customer_id = 1234)
    ```
*   ❌ **片方にインデックスなし**（`phone` にインデックスがない）
    ```sql
    SELECT * FROM customers WHERE city = 'City_5' OR phone = '090-0001-0000';
    ```
    ```text
    Seq Scan on customers  (cost=0.00..2735.00 rows=209 width=69)
      Filter: (((city)::text = 'City_5'::text) OR ((phone)::text = '090-0001-0000'::text))
    ```

`city` 側のインデックスも**使われなくなっている**点に注目してください。`OR` で並べる列は、**全部にインデックスが必要**です。

### ⑥ 選択性が低い（絞り込めない列）

`membership_id`（4種類・各25%）のように、**取りうる値が少ない列**へのインデックスです。

> **選択性が低い列にインデックスを張っても、読むページ数（I/O）は減りません。**
> 25%も該当すれば、**どのページにも該当行がある**ので、結局は全ページ読むことになります。

「速くならない」わけではありません。**行を捨てるCPUの仕事は減る**ので、時間だけ見れば速くなります。

| | 実行時間 | 読んだページ数 |
| :--- | ---: | ---: |
| Seq Scan（強制） | 23.8 ms | 1,235 |
| インデックスあり | **6.0 ms** | **1,258**（むしろ増えている） |

**時間は4倍速いのに、I/Oは1ページも減っていません。** 速くなったのは「75,000行を捨てる処理が消えた」ぶんだけ ── つまり得られるのは**CPU分の改善だけ**で、これを**書き込み負荷（17-1 §8）と容量の代償**と天秤にかけることになります。

*   **1回のクエリを速くしたいだけなら、効果はある**（ただしI/Oは減らない）
*   **更新が多いテーブルなら、まず割に合わない**
*   さらに選択率が上がると、**プランナはインデックスを使うことすらやめます**（ケース4の 90% → `Seq Scan`）

「とりあえずインデックスを張る」が最も無意味になる典型です。**その列で本当に絞り込めるのか**を先に確認しましょう。

```sql
-- 列ごとの異なる値の数を見る（n_distinct が小さいほど絞り込めない）
SELECT attname, n_distinct FROM pg_stats WHERE tablename = 'customers';
```

※ この研修環境では全ページがメモリに載っているので、CPU分の改善がそのまま時間差として出ています。**本番でディスクを読む環境では、改善幅はもっと小さくなります。**

### ⑦ 統計情報が古い

大量に `INSERT` / `UPDATE` した直後は、プランナが「まだデータは少ない」と勘違いしていることがあります。

*   ❌ **症状**：`EXPLAIN` の推定 `rows` と実測 `rows` が大きく乖離している。
*   ⭕ **対処**：`ANALYZE テーブル名;` を実行する。

**実際に計画が変わることを確かめます。**

```sql
CREATE TABLE stale2 (id INT, v TEXT);
INSERT INTO stale2 SELECT gs, md5(gs::text) FROM generate_series(1,200000) gs;
CREATE INDEX ON stale2 (id);

-- ANALYZE せずに実行計画を見る
EXPLAIN SELECT * FROM stale2 WHERE id < 150000;   -- 実際は 149,999行（75%）が該当

ANALYZE stale2;
EXPLAIN SELECT * FROM stale2 WHERE id < 150000;
```

```text
-- ANALYZE 前：統計情報がないので「33%くらいだろう」と推測している
Bitmap Heap Scan on stale2  (cost=1253.09..3753.43 rows=66667 width=36)
  ->  Bitmap Index Scan on stale2_id_idx  (cost=0.00..1236.42 rows=66667 width=0)

-- ANALYZE 後：正しく75%と分かり、全件走査に切り替わった
Seq Scan on stale2  (cost=0.00..4167.00 rows=149585 width=37)
  Filter: (id < 150000)
```

**推定 66,667行 → 149,585行（実際は149,999行）。** 統計情報がないとき、PostgreSQLは「`<` なら3分の1くらい該当するだろう」という既定値で見積もります。実際は75%だったので、**インデックスを使う計画を誤って選んでいました。** 大量の `INSERT` / `UPDATE` の直後は、**autovacuum が追いつく前に `ANALYZE` を手で打つ**のが安全です。

```sql
-- 最後にいつANALYZEされたか確認
SELECT relname, last_analyze, last_autoanalyze
FROM pg_stat_user_tables WHERE relname IN ('customers','orders');

DROP TABLE stale2;   -- 後片付け
```

### 【誤解しやすい】これは「効きます」

**`IS NULL` は効きます。** PostgreSQLはNULLもインデックスに格納します（**Oracleが効かないなどDBによって差があるので注意**）。

```text
Index Scan using idx_customers_city on customers
  Index Cond: (city IS NULL)
```

**`ORDER BY` もインデックスで代替できます。** インデックスはソート済みなので、そのまま読めばソート結果になります。

```sql
EXPLAIN SELECT * FROM orders ORDER BY order_date LIMIT 10;
```

```text
Limit
  ->  Index Scan using idx_orders_order_date on orders     ← Sortノードが無い！
```

降順にすると `Index Scan Backward`（インデックスを逆から辿る）になります。逆にインデックスのない列でソートすると、`Sort` ノードが現れます。

```text
Limit
  ->  Sort   Sort Key: phone                               ← ソート処理が発生
        ->  Seq Scan on customers
```

**`Sort` ノードが出ていたら、インデックスで消せないか**を考える癖をつけてください。ソートは大量データでは `work_mem` を食い、溢れるとディスクを使います（→ 演習 問題8）。

---

## 6. チューニングのチェックリスト

遅いクエリに出会ったら、上から順に確認します。

1.  **`EXPLAIN (ANALYZE, BUFFERS)` を取る。** 憶測で直さない。
2.  **`Buffers` が `pg_class.relpages` と一致していないか。** していたら全件走査。
3.  **インデックスの貼り忘れはないか。** 特に**外部キー**（自動では作られない）。
4.  **インデックスが効かない書き方をしていないか。**
    *   列を加工していないか（関数・計算・キャスト）
    *   否定形（`<>` `NOT IN`）になっていないか
    *   `OR` の全ての列にインデックスがあるか
5.  **`Filter` に出ている条件を `Index Cond` に昇格できないか。**（複合インデックス化）
6.  **複合インデックスの列順は、WHERE句の使い方と合っているか。**
7.  **`Sort` ノードをインデックスで消せないか。**
8.  **統計情報は最新か。** `ANALYZE テーブル名;`
9.  **それでもおかしいなら、そこから先はサーバー設定の話。** 自分で直すものではないので、**先輩やDBA担当に相談**してください（→ §3-3）。
10. **そのインデックスは本当に必要か。** `pg_stat_user_indexes.idx_scan = 0` のものは、容量と書き込み負荷だけを食っています。

ここまでで、**「遅い」と言われたクエリを自分で調べて直せる**ところまで来ました。あとは演習で手を動かして定着させてください。
