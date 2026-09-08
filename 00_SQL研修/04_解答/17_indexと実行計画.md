# 17章 演習 解答：indexと実行計画

以下はすべて **PostgreSQL 17 での実測値**です。皆さんの環境でも、**スキャン方式とページ数は同じになるはず**です。

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

```text
  relname  | ページ数 |  行数   | １ページあたり行数
-----------+----------+---------+--------------------
 customers |     1235 |  100000 |                 81
 orders    |     7255 | 1000000 |                138
```

| | ページ数 | 1ページあたり行数 |
| :--- | ---: | ---: |
| `customers` | **1,235** | **81** |
| `orders` | **7,255** | **138** |

`ctid` の切り替わり：

```text
  ctid  | customer_id
--------+-------------
 (0,81) |          81
 (0,82) |          82
 (1,1)  |          83      ← ここでページが変わる
 (1,2)  |          84
```

**答え：`customer_id = 83`。** 0番ページには82行入り、83行目から1番ページに移りました。8KBの箱が満杯になった瞬間です。

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

#### ① インデックスなし

```text
Seq Scan on customers  (cost=0.00..2485.00 rows=199 width=69)
                       (actual time=0.020..6.001 rows=200 loops=1)
  Filter: ((city)::text = 'City_123'::text)
  Rows Removed by Filter: 99800
  Buffers: shared hit=1235
Execution Time: 6.017 ms
```

| 項目 | 答え |
| :--- | :--- |
| スキャン方式 | **`Seq Scan`** |
| `Buffers` の合計 | **1,235** ページ |
| `Rows Removed by Filter` | **99,800** 件 |

**問題1の `customers` のページ数（1,235）と完全に一致しています。** これが「全ページ読んだ」＝全件走査の証拠です。200件を取るために99,800件を読んで捨てています。

#### ② 散らばりを数える

```text
 該当行 | 使用ページ数
--------+--------------
    200 |          200      ← city 指定：1行につき1ページ
    200 |            3      ← 主キー範囲：3ページに収まる
```

**答え：200ページ 対 3ページ。** どちらも同じ200件なのに、**約67倍**の差があります。`city` は値が循環するように投入したので全ページに散り、`customer_id` は連番なので固まっています。

#### ③ インデックスあり

**【予想】の答え：イ（`Bitmap Heap Scan`）**

```text
Bitmap Heap Scan on customers  (cost=5.83..533.52 rows=199 width=69)
                               (actual time=0.077..0.201 rows=200 loops=1)
  Recheck Cond: ((city)::text = 'City_123'::text)
  Heap Blocks: exact=200
  Buffers: shared hit=200 read=2
  ->  Bitmap Index Scan on idx_customers_city  (actual time=0.056..0.056 rows=200 loops=1)
        Index Cond: ((city)::text = 'City_123'::text)
Execution Time: 0.217 ms
```

| 項目 | 答え |
| :--- | :--- |
| スキャン方式 | **`Bitmap Heap Scan`** |
| `Heap Blocks: exact=` | **200** |
| `Buffers` の合計 | **202** ページ |
| `Execution Time` | 0.217 ms |

**1,235 → 202ページ。約6分の1です。** 実行時間は 6.0ms → 0.22ms（約27倍）。

**なぜ `Index Scan` ではないのか。** ②で数えた通り、200件が200ページに散っているからです。1件ずつ取りに行くと200回のランダムアクセスになり、しかも順序がバラバラです。`Bitmap` なら「必要なページの地図」を先に作り、**ページ番号順に1回ずつ**読めます。`Heap Blocks: exact=200` が「実際に読んだヒープページ数」です。

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

**【予想】の答え：いいえ（変わります）**

#### ① `Pending`（2%）

```text
Index Scan using idx_orders_status on orders  (cost=0.42..606.37 rows=19433 width=25)
                                              (actual time=0.214..4.336 rows=20000 loops=1)
  Index Cond: ((status)::text = 'Pending'::text)
  Buffers: shared hit=128 read=20
Execution Time: 5.156 ms
```

#### ② `Completed`（90%）

```text
Seq Scan on orders  (cost=0.00..19755.00 rows=900300 width=25)
                    (actual time=0.009..71.967 rows=900000 loops=1)
  Filter: ((status)::text = 'Completed'::text)
  Rows Removed by Filter: 100000
  Buffers: shared hit=7255
Execution Time: 89.670 ms
```

| | スキャン方式 | `Buffers` 合計 | `Execution Time` |
| :--- | :--- | ---: | ---: |
| ① `Pending`（2%） | **`Index Scan`** | **148** ページ | 5.2 ms |
| ② `Completed`（90%） | **`Seq Scan`** | **7,255** ページ | 89.7 ms |

②は `orders` の総ページ数（7,255）と一致 ＝ 全件走査です。

**これはバグではなく、プランナの正しい判断です。** 90万件も該当するなら、インデックスで住所を調べてページを飛び回るより、最初から全部順番に読んだ方が安いからです。

> **実務での教訓**：「インデックスが使われない」と相談されたら、**まず何の値で検索しているかを聞いてください。** 値によって計画が変わるのは正常な動作です。

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

#### ① インデックスなし

```text
Nested Loop  (cost=0.29..19763.41 rows=10 width=22) (actual time=1.015..39.913 rows=10 loops=1)
  Buffers: shared hit=7258
  ->  Index Scan using customers_pkey on customers c  (actual time=0.945..0.949 rows=1 loops=1)
        Index Cond: (customer_id = 1234)
        Buffers: shared hit=3
  ->  Seq Scan on orders o  (cost=0.00..19755.00 rows=10 width=12)
                            (actual time=0.068..38.955 rows=10 loops=1)
        Filter: (customer_id = 1234)
        Rows Removed by Filter: 999990          ← ここがボトルネック
        Buffers: shared hit=7255
Execution Time: 39.933 ms
```

| 項目 | 答え |
| :--- | :--- |
| `customers` 側 | `Index Scan`／**3** ページ |
| **`orders` 側** | **`Seq Scan`／7,255 ページ** |
| `Rows Removed by Filter` | **999,990** 件 |
| `Execution Time` | 39.9 ms |

**内側（`orders`）が圧倒的に重い**ことが分かります。全体7,258ページのうち **99.96%** が `orders` の無駄読みです。10件取るために99万9,990件を捨てています。

#### ② インデックスあり

```text
Nested Loop  (cost=4.79..51.92 rows=10 width=22) (actual time=0.132..0.152 rows=10 loops=1)
  Buffers: shared hit=13 read=3
  ->  Index Scan using customers_pkey on customers c  (rows=1 loops=1)
        Buffers: shared hit=3
  ->  Bitmap Heap Scan on orders o  (actual time=0.117..0.136 rows=10 loops=1)
        Recheck Cond: (customer_id = 1234)
        Heap Blocks: exact=10
        Buffers: shared hit=10 read=3
Execution Time: 0.169 ms
```

| 項目 | 答え |
| :--- | :--- |
| `orders` 側のスキャン方式 | **`Bitmap Heap Scan`** |
| 全体の `Buffers` | **16** ページ |
| `Execution Time` | 0.169 ms |

**7,258 → 16ページ（約450分の1）。39.9ms → 0.17ms で約236倍。** `Rows Removed by Filter` は消えました。

> **ここが実務で最も多いインデックス貼り忘れのパターンです。**
> PostgreSQLは**主キーとUNIQUE制約にはインデックスを自動作成しますが、外部キーには作りません。** 外部キーを定義したら、インデックスは自分で張る必要があります。
>
> **読み方のコツ**：結合の実行計画では、**字下げが深い方（内側）が `Seq Scan` になっていないか**を最初に見てください。

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

**【予想】の答え：いいえ（使われません）**

#### ① 両方を指定

```text
Bitmap Heap Scan on orders  (cost=4.48..24.16 rows=5 width=25) (actual time=0.036..0.040 rows=4 loops=1)
  Recheck Cond: ((customer_id = 1234) AND (order_date >= '2025-01-01'::timestamp))
  Heap Blocks: exact=4
  Buffers: shared hit=4 read=3
  ->  Bitmap Index Scan on idx_orders_cust_date
        Index Cond: ((customer_id = 1234) AND (order_date >= '2025-01-01'::timestamp))
```

#### ② 第1キーのみ

```text
Bitmap Heap Scan on orders  (cost=4.50..43.51 rows=10 width=25) (actual time=0.014..0.022 rows=10 loops=1)
  Buffers: shared hit=13
  ->  Bitmap Index Scan on idx_orders_cust_date
        Index Cond: (customer_id = 1234)
```

#### ③ 第2キーのみ

```text
Seq Scan on orders  (cost=0.00..19755.00 rows=35288 width=25)
                    (actual time=100.046..103.772 rows=35201 loops=1)
  Filter: (order_date >= '2025-11-01'::timestamp)
  Rows Removed by Filter: 964799
  Buffers: shared hit=7255
Execution Time: 104.509 ms
```

| | スキャン方式 | `Buffers` 合計 |
| :--- | :--- | ---: |
| ① 両方 | `Bitmap Heap Scan`（index使用） | **7** ページ |
| ② 第1キーのみ | `Bitmap Heap Scan`（index使用） | **13** ページ |
| ③ 第2キーのみ | **`Seq Scan`（index未使用）** | **7,255** ページ |

③は `orders` の総ページ数と一致＝全件走査です。**インデックスがあるのに、まったく使われていません。**

**理由**：複合インデックスは「まず `customer_id` で並べ、同じ `customer_id` の中で `order_date` で並べる」という構造です。**辞書で「2文字目だけ分かっていても引けない」**のと同じで、第1キーが分からないと第2キーの並びを利用できません。

**設計のコツ**：`WHERE` 句で**必ず指定される列を左に**置いてください。

また①では、`Index Cond` に**両方の条件**が入っています。②の `Index Cond` は `customer_id` だけです。**`Index Cond` に入っている条件だけがインデックスで絞れた条件**です（17-2 §3-6）。

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

#### ① カバリングインデックス

```text
Index Only Scan using idx_orders_cust_cover on orders  (cost=0.42..4.60 rows=10 width=12)
                                                       (actual time=0.543..0.545 rows=10 loops=1)
  Index Cond: (customer_id = 500)
  Heap Fetches: 0
  Buffers: shared hit=1 read=3
Execution Time: 0.560 ms
```

| 項目 | 答え |
| :--- | :--- |
| スキャン方式 | **`Index Only Scan`** |
| **`Heap Fetches`** | **0** |
| `Buffers` の合計 | **4** ページ |

**`Heap Fetches: 0` ＝ テーブル本体を一度も読んでいません。** 必要な `customer_id` と `order_date` が両方インデックスの中にあるためです。

> **`VACUUM ANALYZE` を打った理由がここにあります。** インデックスには「その行が今見えるか」という情報がありません。そこで **Visibility Map** で確認するのですが、これを更新するのが `VACUUM` です。打ち忘れると `Heap Fetches` が増えて、この効果が消えます。

#### ② `SELECT *` にすると

```text
Bitmap Heap Scan on orders  (cost=4.50..43.51 rows=10 width=25) (actual time=0.013..0.022 rows=10 loops=1)
  Recheck Cond: (customer_id = 500)
  Heap Blocks: exact=10
  Buffers: shared hit=13
Execution Time: 0.032 ms
```

| 項目 | 答え |
| :--- | :--- |
| スキャン方式 | **`Bitmap Heap Scan`**（`Index Only` ではなくなった） |
| `Buffers` の合計 | **13** ページ |

**4 → 13ページ、9ページ増えました。**

インデックスに入っていない `order_id` と `status` を取るために、結局テーブル本体を読みに行っています。**「`SELECT *` をやめて必要な列だけにする」ことが、そのままI/O削減になる**という分かりやすい例です。

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

#### ①② インデックスがない状態

| | スキャン方式 | `Buffers` | `Execution Time` |
| :--- | :--- | ---: | ---: |
| ① `DATE(order_date) = ...` | `Seq Scan` | 7,255 | 71.0 ms |
| ② 範囲に書き換え | `Seq Scan` | 7,255 | 54.7 ms |

**返る件数はどちらも 1,440 件**（同じ結果です）。

**スキャン方式は変わりませんでした。** ここが大事なポイントで、**「書き換えれば速くなる」わけではありません。** インデックスが無ければどちらも全件走査です。

#### ③ `order_date` にインデックスを作ってから

```text
-- ① DATE() を使った方（インデックスがあっても使われない）
Seq Scan on orders  (cost=0.00..22255.00 rows=5000 width=25)
                    (actual time=19.947..76.007 rows=1440 loops=1)
  Filter: (date(order_date) = '2024-06-01'::date)
  Rows Removed by Filter: 998560
  Buffers: shared hit=7255
Execution Time: 76.059 ms

-- ② 範囲に書き換えた方
Index Scan using idx_orders_order_date on orders  (cost=0.42..59.30 rows=1444 width=25)
                                                  (actual time=0.087..0.249 rows=1440 loops=1)
  Index Cond: ((order_date >= '2024-06-01'::timestamp) AND (order_date < '2024-06-02'::timestamp))
  Buffers: shared hit=11 read=6
Execution Time: 0.289 ms
```

| | スキャン方式 | `Buffers` 合計 | `Execution Time` |
| :--- | :--- | ---: | ---: |
| ① `DATE()` を使った方 | **`Seq Scan`** | **7,255** ページ | 76.1 ms |
| ② 範囲に書き換えた方 | **`Index Scan`** | **17** ページ | 0.289 ms |

**まったく同じインデックスがあるのに、①だけ使われませんでした。7,255ページ 対 17ページ、約426倍の差です。**

**なぜか。** インデックスは **`order_date` の「加工前の生の値」** で並んでいます。`DATE()` を通した後の値がどこにあるかは、**全行を計算してみるまで分かりません**。だから並び順を使えず、全件走査するしかないのです。

**覚え方：「列を触ったら負け」。** 列はそのままにして、計算は右辺（条件側）に寄せてください。

| ❌ 効かない | ⭕ 直し方 |
| :--- | :--- |
| `WHERE DATE(order_date) = '2024-06-01'` | `WHERE order_date >= '2024-06-01' AND order_date < '2024-06-02'` |
| `WHERE age + 1 > 20` | `WHERE age > 19` |
| `WHERE customer_id::text = '1234'` | `WHERE customer_id = 1234` |

> どうしても加工した形で検索したい場合は、**関数インデックス**という手があります。
> ```sql
> CREATE INDEX idx_orders_date_func ON orders (DATE(order_date));
> ```
> これを作れば `DATE(order_date) = '2024-06-01'` でも `Index Scan` になります。

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

#### ① 既定（`work_mem = 4MB`）

```text
Limit  (actual time=... rows=1 loops=1)
  Buffers: shared hit=1235, temp read=1004 written=1006     ← 一時ファイルを使った
  ->  Sort  (actual time=... rows=100000 loops=1)
        Sort Key: phone
        Sort Method: external merge  Disk: 8032kB           ← メモリに収まらなかった
        ->  Seq Scan on customers  (rows=100000 loops=1)
```

#### ②③

| | `Sort Method` | 使ったメモリ | `Execution Time`（目安） |
| :--- | :--- | ---: | ---: |
| ① 既定（4MB） | **`external merge`** | Disk **8,032** kB | 約 57 ms |
| ② 32MB | **`quicksort`** | Memory **11,666** kB | 約 30 ms |
| ③ `LIMIT 10` | **`top-N heapsort`** | Memory **26** kB | 約 10 ms |

**③は②の約450分の1のメモリ**で、しかも一番速く終わっています。

> **実行時間は1回ごとに大きくブレます**（同じクエリを3回流して 87ms → 60ms → 57ms ということが普通に起きます）。**`Sort Method` と使用メモリ量は毎回同じ値になる**ので、そちらで判断してください。

**ポイント3つ。**

1.  **既定の4MBでも溢れていました。** 10万行 × 約80バイト ＝ 約8MB のソートに4MBでは足りません。`Sort Method: external merge` と `temp` が出たら「メモリ不足でディスクを使った」という確定診断です。
2.  **必要量は `Disk:` の値から逆算できます。** 8,032kB と出ているので、16MB程度あれば `quicksort` になります。
3.  **`LIMIT` が付くと `top-N heapsort` に変わります。** 全件を並べ替えるのではなく「上位10件だけ保持する入れ物」を維持しながら流すので、メモリが26kBで済みます。**`ORDER BY` に `LIMIT` を付けられないかを考える**価値があります。

> ⚠️ `work_mem` は「1接続あたり」ではなく「**ソートやハッシュ1つあたり**」の上限です。全体設定を大きくするとメモリを食い潰すので、重い処理だけ `SET LOCAL` で個別に上げるのが定石です。**全体設定を変えるのはサーバー管理者の判断**なので、勝手に上げないでください。

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

```text
 テーブル  |       インデックス       | 使用回数 |  サイズ
-----------+--------------------------+----------+---------
 orders    | idx_orders_order_date    |        0 | 21 MB
 customers | idx_customers_city       |        1 | 688 kB
 orders    | idx_orders_status        |        1 | 6896 kB
 orders    | idx_orders_cust_cover    |        2 | 30 MB
 orders    | idx_orders_cust_date     |        2 | 30 MB
```

※ 使用回数は演習の進め方で前後します。

**問題7で作った `idx_orders_order_date` は、`Index Scan` に1回使われただけで 21MB を消費しています。** 使用回数が `0` のまま残っているインデックスがあれば、それは**検索を1ミリ秒も速くしていないのに、INSERT/UPDATEのたびに更新され、容量を食い続けている**ことになります。

実務では `idx_scan = 0` のインデックスを定期的に探して消します。ただし**「月次バッチでしか使わない」インデックスもある**ので、最低1ヶ月は様子を見てから判断してください。

---

## 演習全体のまとめ

この演習で確認したことを、1行ずつ振り返ってください。

### 解説:

| 問題 | 確認したこと |
| :--- | :--- |
| 1 | 性能の話は最後は「**何ページ読んだか**」。基準は `customers` 1,235 / `orders` 7,255 |
| 2 | インデックスで読むページが激減する。**散らばっていると `Bitmap`** になる |
| 3 | **同じインデックスでも、検索する値によって計画が変わる** |
| 4 | **外部キーにインデックスは自動で作られない**。結合は内側の `Seq Scan` を疑う |
| 5 | 複合インデックスは**左端から**。第2キー単独では使えない |
| 6 | 必要な列が全部インデックスにあれば**本体を読まない**（`Heap Fetches: 0`） |
| 7 | **列を加工したら負け**。インデックスがあっても使われなくなる |
| 8 | ソートが `work_mem` に収まらないと**ディスクに溢れる**（`external merge` / `temp`） |
