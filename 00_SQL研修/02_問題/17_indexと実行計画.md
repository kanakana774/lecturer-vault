# 17章 演習：indexと実行計画

**問題は上から順番に解いてください。** 前の問題で作ったインデックスを次の問題で使います。

> **実行時間（`Execution Time`）だけは環境で変わります。** キャッシュの温まり具合やマシン性能に左右されるので、数値そのものではなく**倍率**を見てください。
> 逆に**ページ数（`Buffers`）は理屈で決まるので、ほぼ同じ数字が出ます。** 大きく違っていたら、初期状態に戻し忘れているか、`ANALYZE` を打ち忘れています。

---

## 準備

### 1. データベースを作る

まだ作っていない場合は [[17_indexと実行計画で使用するテーブル|17_indexと実行計画で使用するテーブル]] の手順でデータベースを作成してください。

### 2. リセット手順（初期状態に戻す）

**この章のリセットはインデックスと統計情報だけです**（テストデータは変わりません）。これを実行すると主キー以外のインデックスが全部消えて、初期状態に戻ります。

```sql
DO $$ DECLARE r RECORD;
BEGIN
    FOR r IN (SELECT indexname FROM pg_indexes
              WHERE schemaname='public' AND indexname NOT LIKE '%_pkey') LOOP
        EXECUTE 'DROP INDEX ' || quote_ident(r.indexname);
    END LOOP;
END $$;
```

続けて、**1行ずつ単独で**実行します。

```sql
VACUUM ANALYZE customers;
```

```sql
VACUUM ANALYZE orders;
```

> ⚠️ **`VACUUM` は他のSQLとまとめて実行できません。** 複数のSQLを選択して一度に流すと、PostgreSQL が1つのトランザクションとして扱うため `ERROR: VACUUM cannot run inside a transaction block` になります。**その行だけを選択して実行**してください。以降の問題でも同じです。

### 3. 並列クエリがオフになっているか確認

```sql
SHOW max_parallel_workers_per_gather;   -- 0 になっていればOK
```

`0` でない場合は `SET max_parallel_workers_per_gather = 0;` を実行してください。実行計画に `Gather` が出て読みにくくなるためです。

> **注意**：問題は**上から順番に**解いてください。前の問題で作ったインデックスを次の問題で使います。

---

## 問題 1: 基準値を確認する
- **目的**: テーブルのページ数と1ページあたりの行数を調べ、以降の「全件走査かどうか」を判断する基準を持つ。

### 問題:
> 対応：**17-1 §1-4、§2-3**

これから何度も出てくる「ページ数」を、最初に頭に入れます。

**やること**

```sql
SELECT relname,
       relpages                    AS ページ数,
       reltuples::bigint           AS 行数,
       round(reltuples / relpages) AS １ページあたり行数
FROM pg_class
WHERE relname IN ('customers', 'orders')
ORDER BY relname;
```

**見るところ**

| | ページ数 | 1ページあたり行数 |
| :--- | ---: | ---: |
| `customers` | | |
| `orders` | | |

この2つのページ数は、**以降の問題で「全件走査かどうか」を判断する基準**になります。覚えておいてください。

**続けて、行がページに詰まっていく様子を見ます。**

```sql
SELECT ctid, customer_id FROM customers
WHERE customer_id BETWEEN 81 AND 84 ORDER BY customer_id;
```

**見るところ**：`ctid` が `(0, ...)` から `(1, ...)` に変わるのは `customer_id` がいくつのときですか？ → **______**

---

### 解答:
```
ここに解答を記入
```

---

## 問題 2: インデックスを張ると何が変わるか
- **目的**: `Seq Scan` と `Index Scan` の実行計画を読み比べ、読むページ数がどれだけ減るかを実測する。

### 問題:
> 対応：**17-1 §3、§4、§6-3、§6-4／17-2 ケース1**

**やること①：インデックスがない状態で検索する**

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers WHERE city = 'City_123';
```

**見るところ①**

| 項目 | 書き取る |
| :--- | :--- |
| スキャン方式 | |
| `Buffers` の合計 | ページ |
| `Rows Removed by Filter` | 件 |
| `Execution Time` | ms |

読んだページ数は、問題1で確認した `customers` のページ数と**一致していますか？** → はい ／ いいえ

**やること②：該当行がどれだけ散らばっているかを数える**

```sql
-- city で絞った200件は、何ページに散っているか
SELECT COUNT(*) AS 該当行,
       COUNT(DISTINCT (ctid::text::point)[0]::int) AS 使用ページ数
FROM customers WHERE city = 'City_123';

-- 比較：主キーの範囲で同じ200件を取ると何ページか
SELECT COUNT(*) AS 該当行,
       COUNT(DISTINCT (ctid::text::point)[0]::int) AS 使用ページ数
FROM customers WHERE customer_id BETWEEN 1 AND 200;
```

**見るところ②**：どちらも200件なのに、使用ページ数は **______ ページ** 対 **______ ページ**。

**【予想】** この状態で `city` にインデックスを張ると、実行計画はどれになると思いますか？

- ア. `Index Scan`
- イ. `Bitmap Heap Scan`

**やること③：インデックスを張って、もう一度実行する**

```sql
CREATE INDEX idx_customers_city ON customers (city);
ANALYZE customers;

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers WHERE city = 'City_123';
```

**見るところ③**

| 項目 | 書き取る |
| :--- | :--- |
| スキャン方式 | |
| `Heap Blocks: exact=` | |
| `Buffers` の合計 | ページ |
| `Execution Time` | ms |

**①と③で、読んだページ数は何分の1になりましたか？** → 約 **______** 分の1

---

### 解答:
```
ここに解答を記入
```

---

## 問題 3: 同じインデックスでも、値によって計画が変わる
- **目的**: 同じインデックスでも、条件に合う行の割合（選択率）によってプランナが使わなくなることを確かめる。

### 問題:
> 対応：**17-2 ケース4**

`orders.status` の分布は `Completed` 90% / `Shipped` 8% / `Pending` 2% です。

**やること**

```sql
CREATE INDEX idx_orders_status ON orders (status);
ANALYZE orders;

-- ① 全体の2%
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE status = 'Pending';

-- ② 全体の90%
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE status = 'Completed';
```

**【予想】** ②は①と同じスキャン方式になると思いますか？ → はい ／ いいえ

**見るところ**

| | スキャン方式 | `Buffers` 合計 | `Execution Time` |
| :--- | :--- | ---: | ---: |
| ① `Pending`（2%） | | ページ | ms |
| ② `Completed`（90%） | | ページ | ms |

**同じテーブル・同じインデックス・同じSQLの形**で、違うのは検索する値だけです。それでも計画が変わりました。

---

### 解答:
```
ここに解答を記入
```

---

## 問題 4: 外部キーにインデックスがない
- **目的**: 外部キー制約はインデックスを作らないことを知り、結合の実行計画がどう変わるか確かめる。

### 問題:
> 対応：**17-2 ケース2**

`orders.customer_id` には外部キー制約が付いています。**しかしインデックスは作られていません。**

**やること①**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.name, o.order_date
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_id = 1234;
```

**見るところ①**

| 項目 | 書き取る |
| :--- | :--- |
| `customers` 側のスキャン方式 | |
| `customers` 側の `Buffers` | ページ |
| **`orders` 側のスキャン方式** | |
| **`orders` 側の `Buffers`** | ページ |
| `Rows Removed by Filter` | 件 |
| `Execution Time` | ms |

**字下げが深い方（内側）に注目してください。** どちらが重いですか？

**やること②：インデックスを張る**

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.name, o.order_date
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
WHERE c.customer_id = 1234;
```

**見るところ②**

| 項目 | 書き取る |
| :--- | :--- |
| `orders` 側のスキャン方式 | |
| 全体の `Buffers` | ページ |
| `Execution Time` | ms |

**何倍速くなりましたか？** → 約 **______** 倍

---

### 解答:
```
ここに解答を記入
```

---

## 問題 5: 複合インデックスの「左端規則」
- **目的**: 複合インデックスが効く条件（左端のキーから順に指定する）を3パターンで確かめる。

### 問題:
> 対応：**17-2 §1-2、§5-④**

**やること：`(customer_id, order_date)` の順で複合インデックスを作り、3パターン試す**

```sql
DROP INDEX idx_orders_customer_id;                         -- 単一列indexは消しておく
CREATE INDEX idx_orders_cust_date ON orders (customer_id, order_date);
ANALYZE orders;

-- ① 両方を指定
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 1234 AND order_date >= '2025-01-01';

-- ② 第1キーだけ指定
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 1234;

-- ③ 第2キーだけ指定
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE order_date >= '2025-11-01';
```

**【予想】** ③ではインデックスが使われると思いますか？ → はい ／ いいえ

**見るところ**

| | スキャン方式 | `Buffers` 合計 |
| :--- | :--- | ---: |
| ① 両方 | | ページ |
| ② 第1キーのみ | | ページ |
| ③ 第2キーのみ | | ページ |

③の結果を、問題1で確認した `orders` のページ数と見比べてください。

---

### 解答:
```
ここに解答を記入
```

---

## 問題 6: テーブル本体を見ない
- **目的**: テーブル本体を読まずに済む `Index Only Scan` の成立条件と、崩れる条件を確かめる。

### 問題:
> 対応：**17-1 §6-5／17-2 ケース3**

**やること①：取得したい列もインデックスに含める**

```sql
CREATE INDEX idx_orders_cust_cover ON orders (customer_id) INCLUDE (order_date);
```

**★ ここで `VACUUM ANALYZE` を単独で実行してください。**（忘れると結果が変わります）

```sql
VACUUM ANALYZE orders;
```

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, order_date FROM orders WHERE customer_id = 500;
```

**見るところ①**

| 項目 | 書き取る |
| :--- | :--- |
| スキャン方式 | |
| **`Heap Fetches`** | |
| `Buffers` の合計 | ページ |

**やること②：`SELECT *` に変えるだけ**

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 500;
```

**見るところ②**

| 項目 | 書き取る |
| :--- | :--- |
| スキャン方式 | |
| `Buffers` の合計 | ページ |

**取得する列を増やしただけで、読んだページ数は何ページ増えましたか？** → **______** ページ

---

### 解答:
```
ここに解答を記入
```

---

## 問題 7: 列を加工してはいけない
- **目的**: 索引列を関数で包むとインデックスが使えなくなることを確かめ、範囲検索に書き換える。

### 問題:
> 対応：**17-2 §5-①**

**やること①：日付を `DATE()` で加工して検索する**

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE DATE(order_date) = '2024-06-01';
```

**やること②：同じ結果になる書き方を、範囲検索に変える**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-06-02';
```

**見るところ①②**：どちらも同じ **______** 件が返ります。スキャン方式は変わりましたか？ → はい ／ いいえ

**やること③：`order_date` にインデックスを作って、①と②をもう一度実行する**

```sql
CREATE INDEX idx_orders_order_date ON orders (order_date);
ANALYZE orders;

-- ①をもう一度
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE DATE(order_date) = '2024-06-01';

-- ②をもう一度
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-06-02';
```

**見るところ③**

| | スキャン方式 | `Buffers` 合計 | `Execution Time` |
| :--- | :--- | ---: | ---: |
| ① `DATE()` を使った方 | | ページ | ms |
| ② 範囲に書き換えた方 | | ページ | ms |

**同じインデックスがあるのに、片方だけ使われませんでした。** なぜでしょうか。

---

### 解答:
```sql
ここに解答を記入
```

---

## 問題 8: メモリに収まらないソート
- **目的**: `work_mem` に収まらないソートが外部マージソートになることを実測し、`LIMIT` の効き方を見る。

### 問題:
> **この問題で見たいこと**
> ソートは**メモリ（`work_mem`）の上で**行われます。**収まらないとディスクに溢れ**、`Buffers` に `temp` が出ます。
> `EXPLAIN` の `Sort Method` に、どのやり方でソートしたかが出るので、それを読み取ってください。
>
> | `Sort Method` の表示 | 意味 |
> | :--- | :--- |
> | `quicksort  Memory: NkB` | メモリ内で完結した（速い） |
> | `external merge  Disk: NkB` | **メモリに収まらずディスクを使った**（遅い） |
> | `top-N heapsort  Memory: NkB` | `LIMIT` があるので上位N件だけ保持した（一番安い） |
>
> ⚠️ `SET work_mem` は**そのセッションだけ**の変更なので安全です。**サーバー全体の設定を決めるのは管理者の仕事**なので、ここでは「値を変えると挙動がどう変わるか」を見るだけにしてください。

`phone` 列にはインデックスがありません。10万件をこの列でソートします。

**やること①：既定の `work_mem` のまま**

```sql
SHOW work_mem;      -- 既定は 4MB

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers ORDER BY phone OFFSET 99999;
```

**見るところ①**

| 項目 | 書き取る |
| :--- | :--- |
| **`Sort Method`** | |
| `Disk:` または `Memory:` | kB |
| `Buffers` の `temp read` / `written` | |
| `Execution Time` | ms |

**やること②：`work_mem` を増やす**

```sql
SET work_mem = '32MB';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers ORDER BY phone OFFSET 99999;
```

戻す
```sql
RESET work_mem;
```

**やること③：`LIMIT` を付ける**

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM customers ORDER BY phone LIMIT 10;
```

**見るところ②③**

| | `Sort Method` | 使ったメモリ | `Execution Time` |
| :--- | :--- | ---: | ---: |
| ① 既定（4MB） | | kB | ms |
| ② 32MB | | kB | ms |
| ③ `LIMIT 10` | | kB | ms |

**③が使ったメモリは、②の何分の1ですか？** → 約 **______** 分の1

---

### 解答:
```
ここに解答を記入
```

---

## 問題 9: 張ったインデックスを棚卸しする
- **目的**: `pg_stat_user_indexes` で使われていないインデックスを見つけ、棚卸しの観点を持つ。

### 問題:

> **この問題で見たいこと**
> `pg_stat_user_indexes.idx_scan` は「そのインデックスが**検索に使われた回数**」です。
> **`idx_scan = 0` は「作ってから一度も使われていない」** という意味で、検索を1ミリ秒も速くしていないのに、
> `INSERT`/`UPDATE` のたびに更新され、容量を食い続けています（17-1 §8）。実務では定期的にこれを棚卸しします。
>
> ⚠️ ただし **`idx_scan = 0` でもすぐ消してはいけません。** 「月末バッチでしか使わない」インデックスは
> 平常時ずっと0に見えます。**最低1ヶ月**は様子を見てから判断してください。

ここまでで6本のインデックスを作りました。どれだけ使われたか見てみましょう。

```sql
SELECT s.relname AS テーブル, s.indexrelname AS インデックス,
       s.idx_scan AS 使用回数,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS サイズ
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE NOT i.indisprimary AND NOT i.indisunique
ORDER BY s.idx_scan;
```

**使用回数が `0` のインデックスはありますか？** それは何MB使っていますか？

実務では、この「使われていないのに容量と書き込み負荷だけ食っているインデックス」を定期的に探して消します。

### 解答:
```
ここに解答を記入
```

---

## 演習全体のまとめ

この演習で確認したことを、1行ずつ振り返ってください。

