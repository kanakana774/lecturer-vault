
## CASE式による条件分岐

### CASE式とは

`CASE`式は、条件に応じて**違う値を返す**ための構文です。

他の言語の `if` 文や `switch` 文に見た目は似ていますが、**`CASE`式は「文」ではなく「式」です。**
処理を実行するのではなく、`1 + 1` や `price * 2` と同じように**ひとつの値になります**。

この違いがそのまま、`CASE`式の使いどころを決めます。**値を書ける場所には、どこにでも書けます。**

| 書ける場所 | 何が変わるか |
| :--- | :--- |
| `SELECT`句 | 列の中身が変わる |
| `ORDER BY`句 | 並び順が変わる |
| `WHERE`句 | 絞り込みの条件が変わる |
| `UPDATE` の `SET`句 | 更新後の値が変わる |
| 関数の引数 | その関数の計算ルールが変わる |

逆に、`CASE`式の中に `INSERT` や `UPDATE` を書くことはできません。返せるのは値だけです。

---

### 0. この章で使うテーブル

**[[02_DDL（前半用）]] の4テーブルをそのまま使います。** 新しく作るものはありません。

この章でよく使うのは次の5つです。

| 使うもの | 中身 | 狙い |
| :--- | :--- | :--- |
| `products_mst.price` | 750 〜 29,800 の幅がある | 数値の範囲で分ける（→ §1-1） |
| `products_mst.category` | `Electronics` `Books` `Home & Kitchen` `Food` `Stationery` `Toys` の6種 | 値そのもので分ける（→ §1-2） |
| `products_mst.memo` | 23件のうち**7件が `NULL`**（未入力） | `NULL` の扱い（→ §1-3、§4-1） |
| `products_mst.stock_quantity` | **0 の商品が4件**ある | 境界のある分類（→ §3-1） |
| `customers_mst.deleted_at` | **退会済みが1人**（山田 恵美）、残りは `NULL` | `NULL` を状態として読む（→ §3-1） |

`UPDATE` を扱う §3-4 以外は `SELECT` だけなので、データは変わりません。

> [!note]- 結果に `NULL` が出てくる例があります
> psql は `NULL` を既定で**空欄**として表示します。この資料では `NULL` と分かるように表示しているので、
> 手元で同じ見た目にしたい場合は先に次を実行してください。
>
> ```
> \pset null 'NULL'
> ```

---

## 1. 2つの書き方

`CASE`式には**検索CASE式**と**シンプルCASE式**の2つの書き方があります。
迷ったら検索CASE式を選んでください。**書けることが多いのはこちらです。**

### 1-1. 検索CASE式：条件で分ける

`WHEN` に**条件式**を書きます。比較演算子・論理演算子・`IS NULL` など、`WHERE`句に書けるものが書けます。

```sql
CASE
  WHEN 条件式1 THEN 結果1
  WHEN 条件式2 THEN 結果2
  ...
  [ELSE デフォルト結果]
END
```

価格を3段階に分けてみます。

```sql
SELECT product_id, product_name, price,
  CASE
    WHEN price >= 10000 THEN '高額'
    WHEN price >= 3000  THEN '中価格'
    ELSE '低価格'
  END AS price_band
FROM products_mst
WHERE category = 'Electronics'
ORDER BY product_id;
```

```
 product_id |     product_name     |  price   | price_band
------------+----------------------+----------+------------
          1 | ワイヤレスイヤホン   | 12800.00 | 高額
          4 | スマートウォッチ     | 29800.00 | 高額
          8 | USB 充電器           |  1500.00 | 低価格
         11 | ゲーミングマウス     |  7800.00 | 中価格
         14 | ポータブルバッテリー |  3980.00 | 中価格
(5 rows)
```

`price` 列はそのまま残っていて、**その隣に新しい列ができている**ことに注目してください。
`CASE`式は元のデータを書き換えるのではなく、値を計算して返しているだけです。

### 1-2. シンプルCASE式：値で分ける

`CASE` の直後に**列名**を書き、`WHEN` にはその列がとる**値**を並べます。
「1つの列が何であるか」だけで分かれる場合は、こちらのほうが短く書けます。

```sql
CASE 列名
  WHEN 値1 THEN 結果1
  WHEN 値2 THEN 結果2
  ...
  [ELSE デフォルト結果]
END
```

英語のカテゴリ名を日本語に読み替えます。

```sql
SELECT product_id, product_name, category,
  CASE category
    WHEN 'Electronics'    THEN '家電'
    WHEN 'Books'          THEN '書籍'
    WHEN 'Home & Kitchen' THEN '生活用品'
    ELSE 'その他'
  END AS category_ja
FROM products_mst
WHERE product_id IN (1, 2, 3, 6, 16)
ORDER BY product_id;
```

```
 product_id |      product_name      |    category    | category_ja
------------+------------------------+----------------+-------------
          1 | ワイヤレスイヤホン     | Electronics    | 家電
          2 | SQL 入門               | Books          | 書籍
          3 | 電気ケトル             | Home & Kitchen | 生活用品
          6 | オーガニックコーヒー豆 | Food           | その他
         16 | 多機能ボールペン       | Stationery     | その他
(5 rows)
```

シンプルCASE式は、検索CASE式で `WHEN category = 'Electronics' THEN ...` と書くのと同じ意味です。
**`=` による比較に固定されている**ぶん短く書けますが、範囲や複数条件は書けません。

### 1-3. シンプルCASE式は `NULL` を捕まえられない

> [!warning] ⚠️ `WHEN NULL` は書けても、絶対に一致しません
> シンプルCASE式は内部で `列 = 値` の比較をしています。`NULL` との `=` 比較は真でも偽でもなく
> **UNKNOWN** になるため、`WHEN NULL THEN ...` は一度も選ばれません。

未入力の `memo` を見分けようとした例です。

```sql
SELECT product_id, memo,
  CASE memo WHEN NULL THEN '未入力' ELSE '入力あり' END AS simple_case,
  CASE WHEN memo IS NULL THEN '未入力' ELSE '入力あり' END AS searched_case
FROM products_mst
WHERE product_id IN (1, 2, 6, 21)
ORDER BY product_id;
```

```
 product_id |                 memo                 | simple_case | searched_case
------------+--------------------------------------+-------------+---------------
          1 | 高音質でノイズキャンセリング機能付き | 入力あり    | 入力あり
          2 | NULL                                 | 入力あり    | 未入力
          6 | NULL                                 | 入力あり    | 未入力
         21 | NULL                                 | 入力あり    | 未入力
(4 rows)
```

`memo` が `NULL` の3件が、シンプルCASE式では**「入力あり」に分類されてしまっています。**
エラーにならず、黙って間違った答えを返すのがこの罠のたちの悪いところです。

**`NULL` を判定したいときは検索CASE式で `IS NULL` を書く。** これが唯一の書き方です。

---

## 2. 3つの規則

### 2-1. 上から順に評価され、最初に真になった枝で止まる

`WHEN` は**書いた順**に評価され、最初に真になった `THEN` の値を返してそこで終わります。
残りの `WHEN` は見に行きません。**つまり記述順序が答えを変えます。**

さきほどの価格帯を、順序だけ入れ替えて並べてみます。

```sql
SELECT product_name, price,
  CASE WHEN price >=  3000 THEN '中価格'
       WHEN price >= 10000 THEN '高額'
       ELSE '低価格' END AS 誤った順序,
  CASE WHEN price >= 10000 THEN '高額'
       WHEN price >=  3000 THEN '中価格'
       ELSE '低価格' END AS 正しい順序
FROM products_mst
WHERE product_id IN (1, 4, 5, 8)
ORDER BY product_id;
```

```
     product_name      |  price   | 誤った順序 | 正しい順序
-----------------------+----------+------------+------------
 ワイヤレスイヤホン    | 12800.00 | 中価格     | 高額
 スマートウォッチ      | 29800.00 | 中価格     | 高額
 Python プログラミング |  3200.00 | 中価格     | 中価格
 USB 充電器            |  1500.00 | 低価格     | 低価格
(4 rows)
```

12,800円の商品が「中価格」になりました。`price >= 3000` が先に真になるので、
後ろの `price >= 10000` には**到達しません**。「高額」は一度も返らない枝になっています。

> [!warning] ⚠️ 条件が重なるときは、狭いほうを先に書く
> `price >= 10000` は `price >= 3000` に含まれます。**含まれる側（狭い側）を先に書く。**
> 条件が互いに重ならない場合（`category = 'Books'` と `category = 'Food'` など）は順序を気にしなくてよいので、
> 気をつけるのは範囲で分けるときです。

### 2-2. `ELSE` を省くと `NULL` になる

`ELSE` は省略できます。省略して**どの `WHEN` にも当たらなかった行は `NULL`** になります。
エラーにはなりません。

```sql
SELECT product_id, category,
  CASE category WHEN 'Books' THEN '書籍' END AS else_なし,
  CASE category WHEN 'Books' THEN '書籍' ELSE 'その他' END AS else_あり
FROM products_mst
WHERE product_id IN (1, 2, 5)
ORDER BY product_id;
```

```
 product_id |  category   | else_なし | else_あり
------------+-------------+-----------+-----------
          1 | Electronics | NULL      | その他
          2 | Books       | 書籍      | 書籍
          5 | Books       | 書籍      | 書籍
(3 rows)
```

`NULL` になって困らない場面（→ §3-4b）と、致命的になる場面があります。
**`ELSE` を書かないのは「書き忘れ」ではなく「`NULL` でよい」という判断**だと考えてください。

### 2-3. `THEN` / `ELSE` の型はそろえる

すべての枝が**同じ型の値を返す**必要があります。

```sql
SELECT product_name,
  CASE WHEN price >= 10000 THEN 100 ELSE '未設定' END AS x
FROM products_mst;
```

```
ERROR:  invalid input syntax for type integer: "未設定"
LINE 2:   CASE WHEN price >= 10000 THEN 100 ELSE '未設定' END AS x
                                                 ^
```

最初の枝が数値（`integer`）なので、式全体の型が `integer` に決まります。
そこへ文字列 `'未設定'` を返そうとしてエラーになりました。

どちらかに寄せれば通ります。数値と文字列を1つの列に混ぜたい場合は、**文字列にそろえます。**

```sql
SELECT product_name,
  CASE WHEN price >= 10000 THEN '100' ELSE '未設定' END AS x
FROM products_mst WHERE product_id IN (1, 8) ORDER BY product_id;
```

```
    product_name    |   x
--------------------+--------
 ワイヤレスイヤホン | 100
 USB 充電器         | 未設定
(2 rows)
```

> [!warning] ⚠️ 「文字列にそろえたら通った」で済ませない
> 数値のつもりの列を文字列にすると、その先の計算や並べ替えが**辞書順**になります（→ §3-2）。
> そろえる前に「この列はほんとうに1つの列でよいのか」を考えてください。

---

## 3. 値を書ける場所には、どこにでも書ける

ここからは同じ `CASE`式を、置く場所を変えて使っていきます。
**構文は §1・§2 で全部です。新しい書き方は出てきません。**

### 3-1. `SELECT`句：列を作る

いちばん多い使い方です。生のデータから、**人が読める意味を持った列**を作ります。

```sql
SELECT product_id, product_name, stock_quantity,
  CASE
    WHEN stock_quantity = 0   THEN '在庫切れ'
    WHEN stock_quantity < 100 THEN '残りわずか'
    ELSE '在庫あり'
  END AS stock_status
FROM products_mst
WHERE product_id IN (1, 3, 7, 17)
ORDER BY product_id;
```

```
 product_id |    product_name    | stock_quantity | stock_status
------------+--------------------+----------------+--------------
          1 | ワイヤレスイヤホン |            150 | 在庫あり
          3 | 電気ケトル         |             80 | 残りわずか
          7 | 高性能ブレンダー   |              0 | 在庫切れ
         17 | 木製パズル         |              0 | 在庫切れ
(4 rows)
```

`NULL` が「値が無い」以上の意味を持っている列でも同じことができます。
`customers_mst.deleted_at` は論理削除のメタカラムなので、**`NULL` かどうかが会員状態そのもの**です。

```sql
SELECT customer_id, customer_name,
  CASE WHEN deleted_at IS NULL THEN '有効' ELSE '退会済み' END AS 状態
FROM customers_mst
WHERE customer_id IN (3, 4, 5)
ORDER BY customer_id;
```

```
 customer_id | customer_name |   状態
-------------+---------------+----------
           3 | 田中 健太     | 有効
           4 | 山田 恵美     | 退会済み
           5 | 渡辺 剛       | 有効
(3 rows)
```

### 3-2. `ORDER BY`句：並び順を決める

`ORDER BY` は `CASE`式が**返した値**を比較します。数値を返せば数値順、文字列を返せば辞書順です。

業務上の優先度（書籍 → 家電 → その他）で並べてみます。

```sql
SELECT product_id, product_name, category
FROM products_mst
WHERE product_id IN (1, 2, 3, 6, 16)
ORDER BY
  CASE category
    WHEN 'Books'       THEN 1
    WHEN 'Electronics' THEN 2
    ELSE 3
  END,
  product_id;
```

```
 product_id |      product_name      |    category
------------+------------------------+----------------
          2 | SQL 入門               | Books
          1 | ワイヤレスイヤホン     | Electronics
          3 | 電気ケトル             | Home & Kitchen
          6 | オーガニックコーヒー豆 | Food
         16 | 多機能ボールペン       | Stationery
(5 rows)
```

同じ順位の中は `product_id` で並べています。**`ORDER BY` に2つ目のキーを書かないと、
同順位の並びは保証されません。**

> [!warning] ⚠️ 数値のつもりで文字列を返すと辞書順になる
> 並び順のキーを引用符で囲むと文字列になり、`'10'` が `'9'` より前に来ます。
>
> ```sql
> SELECT product_id, category
> FROM products_mst
> WHERE product_id IN (1, 2, 3)
> ORDER BY
>   CASE category WHEN 'Books' THEN '9' WHEN 'Electronics' THEN '10' ELSE '20' END;
> ```
>
> ```
>  product_id |    category
> ------------+----------------
>           1 | Electronics     ← '10'
>           3 | Home & Kitchen  ← '20'
>           2 | Books           ← '9'
> (3 rows)
> ```
>
> 順位を表す値は数値で返してください。文字列で順位を作るなら `'A'` `'B'` `'Z'` のように**桁数をそろえます。**

### 3-3. `WHERE`句：真偽値を返す

`WHERE`句は真偽値を受け取る場所なので、`THEN` に真偽値を返せば `CASE`式も書けます。

```sql
SELECT product_id, category, price, stock_quantity
FROM products_mst
WHERE
  CASE
    WHEN category = 'Electronics' THEN price >= 10000
    WHEN category = 'Books'       THEN stock_quantity >= 200
    ELSE FALSE
  END
ORDER BY product_id;
```

```
 product_id |  category   |  price   | stock_quantity
------------+-------------+----------+----------------
          1 | Electronics | 12800.00 |            150
          2 | Books       |  2500.00 |            200
          4 | Electronics | 29800.00 |            100
         13 | Books       |  1800.00 |            250
(4 rows)
```

**ただし、ふつうは `AND` / `OR` で書きます。** 同じ結果が短く読めます。

```sql
SELECT product_id, category, price, stock_quantity
FROM products_mst
WHERE
  (category = 'Electronics' AND price >= 10000)
  OR
  (category = 'Books' AND stock_quantity >= 200)
ORDER BY product_id;
```

同じ4行が返ります。`AND` / `OR` のほうを選ぶ理由は2つあります。

- **条件のブロックが括弧で見えている。** 「どの条件がどの分岐に属するか」を目で追える
- **条件を1つ足すときに1行足すだけで済む。** `CASE` だと `WHEN` の順序まで考え直すことになる

> [!warning] ⚠️ `WHERE`句の `CASE` は絞り込みを列の値から計算するので、その列のインデックスが使いにくくなります
> 実行計画の読み方は [[17-2_実践_EXPLAINの読み方|17章]] で扱います。ここでは「`AND` / `OR` で書けるなら
> そちらにする」と覚えておいてください。

#### `CASE` を入れ子にしない

`CASE` を重ねると、どこまでが1つの条件か分からなくなります。

```sql
SELECT product_id, category, price, stock_quantity
FROM products_mst
WHERE
  CASE
    WHEN stock_quantity >= 100 THEN (      -- 在庫条件
      CASE
        WHEN price > 5000 THEN (           -- 価格条件
          CASE WHEN category = 'Electronics' THEN TRUE ELSE FALSE END
        )
        ELSE FALSE
      END
    )
    ELSE TRUE                              -- 在庫が少ないものは全部見る
  END
ORDER BY product_id;
```

同じ条件を `AND` / `OR` で書くとこうなります。

```sql
SELECT product_id, category, price, stock_quantity
FROM products_mst
WHERE
  (stock_quantity >= 100 AND price > 5000 AND category = 'Electronics')
  OR
  (stock_quantity < 100)
ORDER BY product_id;
```

```
 product_id |    category    |  price   | stock_quantity
------------+----------------+----------+----------------
          1 | Electronics    | 12800.00 |            150
          3 | Home & Kitchen |  4500.00 |             80
          4 | Electronics    | 29800.00 |            100
          7 | Home & Kitchen |  9800.00 |              0
          9 | Books          |  3800.00 |             90
         11 | Electronics    |  7800.00 |             70
         17 | Toys           |  3300.00 |              0
         18 | Toys           |  8800.00 |              0
         19 | Books          |  2500.00 |             60
         20 | Food           |  1200.00 |             30
         23 | Toys           |  2400.00 |              0
(11 rows)
```

どちらも同じ11行です。**入れ子3段が2行になりました。**
条件のかたまりを論理演算子で分けるのが、読めるSQLを書くこつです。

### 3-4. `UPDATE` の `SET`句：更新後の値を分ける

`SET` の右辺は値を書く場所なので、`CASE`式が書けます。
**これによって「1つの `UPDATE` 文で、行ごとに違う値を入れる」ことができます。**

カテゴリごとに違う割引率をかけてみます。

```sql
BEGIN;
UPDATE products_mst
SET price = CASE category
      WHEN 'Food' THEN price * 0.9   -- 10%引き
      WHEN 'Toys' THEN price * 0.8   -- 20%引き
      ELSE price                     -- それ以外は据え置き
    END
WHERE product_id IN (2, 6, 15, 17, 18)
RETURNING product_id, category, price;
ROLLBACK;
```

```
 product_id | category |  price
------------+----------+---------
          2 | Books    | 2500.00
          6 | Food     | 1620.00
         15 | Food     | 1080.00
         17 | Toys     | 2640.00
         18 | Toys     | 7040.00
(5 rows)

UPDATE 5
ROLLBACK
```

`CASE` を使わずに同じことをすると `UPDATE` 文が2本（カテゴリの数だけ）必要になり、
テーブルを2回走ることになります。

> [!note]- `BEGIN;` … `ROLLBACK;` で囲んでいるのはなぜか
> `UPDATE` の結果を確かめたいけれど、データは元に戻したいからです。
> `ROLLBACK` すれば変更は消えるので、テストデータを作り直す必要がありません。
> トランザクションのしくみは [[15-1_導入_トランザクションとACID|15章]] で扱います。

#### `SET` 句で `ELSE` を省くと、対象外の行が `NULL` に潰れる

§2-2 の「`ELSE` なし → `NULL`」が、`UPDATE` では**データの消失**として現れます。

```sql
BEGIN;
UPDATE products_mst
SET memo = CASE WHEN stock_quantity = 0 THEN '在庫切れ' END
WHERE product_id IN (1, 3, 7)
RETURNING product_id, stock_quantity, memo;
ROLLBACK;
```

```
 product_id | stock_quantity |   memo
------------+----------------+----------
          1 |            150 | NULL
          3 |             80 | NULL
          7 |              0 | 在庫切れ
(3 rows)

UPDATE 3
ROLLBACK
```

在庫があった2件の `memo` が**消えました。** `WHERE` で3行を対象にしているので、
`CASE` が `NULL` を返した行にも `NULL` が書き込まれます。

**`ELSE` に元の列を書いて、据え置きにします。**

```sql
BEGIN;
UPDATE products_mst
SET memo = CASE WHEN stock_quantity = 0 THEN '在庫切れ' ELSE memo END
WHERE product_id IN (1, 3, 7)
RETURNING product_id, stock_quantity, memo;
ROLLBACK;
```

```
 product_id | stock_quantity |                 memo
------------+----------------+--------------------------------------
          1 |            150 | 高音質でノイズキャンセリング機能付き
          3 |             80 | 1L 容量、自動電源オフ機能
          7 |              0 | 在庫切れ
(3 rows)

UPDATE 3
ROLLBACK
```

> [!warning] ⚠️ `SET 列 = CASE ... END` に `ELSE` が無いものは、まず疑う
> `WHERE` で行を絞っても、`SET` は**その行すべてに書き込みます。**
> 「更新しない」を表現したいなら `ELSE 列名`、または `WHERE` 側で対象を絞ります。

### 3-5. 関数の引数：計算ルールを差し替える

関数の**中身**に `CASE`式を書くと、関数は1つのまま、ルールだけを行ごとに変えられます。

価格の桁数によって表示書式を変える例です（`TO_CHAR` は [[00_SQL研修/01_講義資料/04_関数|04_関数]] §2.4）。

```sql
SELECT product_id, product_name, price,
  TO_CHAR(
    price,
    CASE WHEN price >= 10000 THEN 'FM999,999円' ELSE 'FM9999円' END
  ) AS 表示価格
FROM products_mst
WHERE product_id IN (1, 4, 8, 15)
ORDER BY product_id;
```

```
 product_id |    product_name    |  price   | 表示価格
------------+--------------------+----------+----------
          1 | ワイヤレスイヤホン | 12800.00 | 12,800円
          4 | スマートウォッチ   | 29800.00 | 29,800円
          8 | USB 充電器         |  1500.00 | 1500円
         15 | 国産はちみつ       |  1200.00 | 1200円
(4 rows)
```

`TO_CHAR` を**1箇所書くだけで済む**のがこの形の利点です。
逆に `CASE` の外側に関数を書くと（`CASE WHEN ... THEN TO_CHAR(...) ELSE TO_CHAR(...) END`）、
関数が枝の数だけ増え、あとで書式を直すときに全部直すことになります。

---

## 4. `CASE`式を書かなくてよいとき

`CASE`式は何でも書けるので、**短い書き方があるのに `CASE` で書いてしまう**ことが起きます。

### 4-1. `NULL` を別の値に置き換えるだけ → `COALESCE`

```sql
SELECT product_id,
  CASE WHEN memo IS NULL THEN '（メモなし）' ELSE memo END AS case_で書く,
  COALESCE(memo, '（メモなし）')                            AS coalesce_で書く
FROM products_mst
WHERE product_id IN (1, 2, 6)
ORDER BY product_id;
```

```
 product_id |             case_で書く              |           coalesce_で書く
------------+--------------------------------------+--------------------------------------
          1 | 高音質でノイズキャンセリング機能付き | 高音質でノイズキャンセリング機能付き
          2 | （メモなし）                         | （メモなし）
          6 | （メモなし）                         | （メモなし）
(3 rows)
```

結果は同じです。`COALESCE`（[[00_SQL研修/01_講義資料/04_関数|04_関数]] §3.1）は**「`NULL` なら次の値」に特化した `CASE`式**だと考えてください。
`NULL` の置き換えだけなら `COALESCE`、それ以外の条件が混ざるなら `CASE` です。

### 4-2. 真偽値がほしいだけ → 条件式をそのまま書く

```sql
SELECT product_id, stock_quantity,
  CASE WHEN stock_quantity = 0 THEN TRUE ELSE FALSE END AS 冗長な書き方,
  stock_quantity = 0                                    AS 素直な書き方
FROM products_mst
WHERE product_id IN (7, 8, 17)
ORDER BY product_id;
```

```
 product_id | stock_quantity | 冗長な書き方 | 素直な書き方
------------+----------------+--------------+--------------
          7 |              0 | t            | t
          8 |            500 | f            | f
         17 |              0 | t            | t
(3 rows)
```

条件式そのものが `TRUE` / `FALSE` を返す**式**なので、`CASE` で包む必要はありません。
`CASE WHEN 条件 THEN TRUE ELSE FALSE END` と書きたくなったら、条件だけを書いてください。

---

## 5. まとめ

- **`CASE`式は文ではなく式。** 値を書ける場所には全部書ける（`SELECT` / `ORDER BY` / `WHERE` / `SET` / 関数の引数）
- **検索CASE式（`CASE WHEN 条件`）を基本にする。** シンプルCASE式（`CASE 列 WHEN 値`）は `=` 比較に固定されている
- **`NULL` を判定するなら検索CASE式で `IS NULL`。** シンプルCASE式の `WHEN NULL` は一致しない（→ §1-3）
- **`WHEN` は上から順。** 範囲で分けるときは狭い条件を先に書く（→ §2-1）
- **`ELSE` を省くと `NULL`。** `UPDATE` の `SET` では、それがデータの消失になる（→ §3-4）
- **`WHERE`句は `AND` / `OR` で書く。** `CASE` でも書けるが、読みにくくインデックスも使いにくい（→ §3-3）
- **短い書き方があるなら使う。** `NULL` の置き換えは `COALESCE`、真偽値は条件式そのまま（→ §4）

集計と組み合わせた使い方（「カテゴリごとに、在庫切れの件数だけ数える」など）は、
集計関数を学んだあとの [[07_集約関数]] §6・§7 で扱います。
