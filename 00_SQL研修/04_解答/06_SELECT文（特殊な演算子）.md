# 06章 演習 解答：SELECT文（特殊な演算子）

**PostgreSQL 17 で実際に動かした結果を載せています。** 使用するテーブルは02章で作成した `products_mst` / `customers_mst` / `orders_trn` / `order_details_trn` です。
問題 9〜12 は `UPDATE` / `DELETE` でデータを変更しますが、`BEGIN;` … `ROLLBACK;` で囲む形にしてあります。

---

## 準備

### 使用するテーブル

02章で作成した `products_mst` / `customers_mst` / `orders_trn` / `order_details_trn` をそのまま使います。この章で新しく作るテーブルはありません。

### リセット手順

**データを変えるのは問題 9〜12 だけです。** 他の問はすべて `SELECT` なので、データは変わりません。
問題 9〜12 は `UPDATE` / `DELETE` を使いますが、`BEGIN;` … `ROLLBACK;` で囲む形にしてあるので、**そのとおりに実行すればリセットは要りません。**

`ROLLBACK` を忘れて確定してしまった場合は、**DBを作り直して入れ直します。**

1. `DROP DATABASE` → `CREATE DATABASE`
2. DDL を実行する
3. テストデータの `INSERT` を実行する

戻ったかどうかは次のSQLで確認します。**23 / 28 / Toys の3件がすべて在庫0** なら初期状態です。

```sql
SELECT (SELECT COUNT(*) FROM products_mst)      AS products,
       (SELECT COUNT(*) FROM order_details_trn) AS order_details;

SELECT product_id, product_name, stock_quantity
FROM products_mst
WHERE category = 'Toys'
ORDER BY product_id;
```

---

## 問題 1: 特定の範囲内の価格を持つ商品を検索する
- **目的**: `WHERE` 句と `BETWEEN` 演算子を使用して、数値範囲内のデータを効率的に絞り込む方法を理解する。

### 問題:
`products_mst` テーブルから、価格が **5,000 円以上 10,000 円以下** の商品の情報を取得してください。

### 解答:
```sql
SELECT *
FROM products_mst
WHERE price BETWEEN 5000 AND 10000;
```

**別解: AND 演算子を使う**
```sql
SELECT *
FROM products_mst
WHERE price >= 5000 AND price <= 10000;
```

### 解説:
`BETWEEN A AND B` は `>= A AND <= B` と同じで、**両端を含みます**。5,000円ちょうど・10,000円ちょうどの商品も対象になる点を確認してください。

---

## 問題 2: 複数のカテゴリの商品を検索する
- **目的**: `WHERE` 句と `IN` 演算子を使用して、指定した複数の値の「いずれか」に一致するデータを絞り込む方法を理解する。

### 問題:
`products_mst` テーブルから、カテゴリが **'Books'** または **'Food'** の商品の情報を取得してください。

### 解答:
```sql
SELECT *
FROM products_mst
WHERE category IN ('Books', 'Food');
```

**別解: OR 演算子を使う**
```sql
SELECT *
FROM products_mst
WHERE category = 'Books' OR category = 'Food';
```

### 解説:
項目が増える場合、`OR` を連ねるよりも `IN` を使う方がSQLがスッキリして読みやすくなります。

---

## 問題 3: 特定の文字列を含む商品名を検索する
- **目的**: `WHERE` 句と `LIKE` 演算子（`%` ワイルドカード）を使用して、部分一致検索を行う方法を理解する。

### 問題:
`products_mst` テーブルから、商品名(`product_name`)に **「ワイヤレス」** という文字列が含まれる商品を全て取得してください。

### 解答:
```sql
SELECT *
FROM products_mst
WHERE product_name LIKE '%ワイヤレス%';
```

---

## 問題 4: 特定の条件を満たす顧客と注文を組み合わせる
- **目的**: 複数の `WHERE` 条件を `AND` や `OR` で組み合わせ、結果を `ORDER BY` で並び替える複合的なクエリを作成する。

### 問題:
`customers_mst` テーブルから、以下の条件を全て満たす顧客の情報を取得してください。

1. 登録日が **2023年3月1日以降**
2. メールアドレスに **「example.com」** が含まれる

結果は **登録日が新しい順** に表示してください。

### 解答:
```sql
SELECT customer_name, email, created_date
FROM customers_mst
WHERE created_date >= '2023-03-01'
  AND email LIKE '%example.com%'
ORDER BY created_date DESC;
```

---

## 問題 5: 特定の件数のみ取得する (LIMIT)
- **目的**: `LIMIT` 句を使用して、取得する行の数を制限する方法を理解する。

### 問題:
`products_mst` テーブルから、価格が高い順に並べた際の **上位 3 件** の商品名と価格を取得してください。

### 解答:
```sql
SELECT product_name, price
FROM products_mst
ORDER BY price DESC
LIMIT 3;
```

---

## 問題 6: 特定の開始位置からデータを取得する (OFFSET)
- **目的**: `OFFSET` 句と `LIMIT` 句を組み合わせて、特定の開始位置からデータを取得する方法（ページネーションの基礎）を理解する。

### 問題:
`products_mst` テーブルから、価格が高い順に並べた際に、**4 番目から 2 件** （つまり、4位と5位）の商品名と価格を取得してください。

### 解答:
```sql
SELECT product_name, price
FROM products_mst
ORDER BY price DESC
LIMIT 2 OFFSET 3;
```

### 解説:
`OFFSET 3` は「最初の3件を飛ばす」という意味なので、結果として4件目からデータが取得されます。

---

## 問題 7: LIKE 演算子とワイルドカードの応用
- **目的**: ワイルドカード（`_` アンダースコア）を含めた `LIKE` 演算子のパターンマッチング能力を深める。

### 問題:
`products_mst` テーブルから、商品名の **2文字目が「ー」（長音記号）** である商品を全て取得してください。
（例：「データ分析の基礎」など）

### 解答:
```sql
SELECT *
FROM products_mst
WHERE product_name LIKE '_ー%';
```

### 期待結果:
| product_id | product_name | category | price |
| ---: | :--- | :--- | ---: |
| 6 | オーガニックコーヒー豆 | Food | 1800.00 |
| 9 | データ分析の基礎 | Books | 3800.00 |
| 11 | ゲーミングマウス | Electronics | 7800.00 |
| 14 | ポータブルバッテリー | Electronics | 3980.00 |

### 解説:
`%` は0文字以上の任意の文字列を表しますが、`_` は「任意の1文字」を表します。

---

## 問題 8: 特定期間の顧客の登録情報検索
- **目的**: 日付型データの範囲検索と並び替えを正確に行う。

### 問題:
`customers_mst` テーブルから、**2023年3月1日 ～ 2023年7月31日** の間に登録された顧客の、顧客名と登録日を取得してください。
結果は **登録日が古い順** に表示してください。

### 解答:
```sql
SELECT customer_name, created_date
FROM customers_mst
WHERE created_date BETWEEN '2023-03-01' AND '2023-07-31'
ORDER BY created_date ASC;
```

### 解説:
`created_date` は `DATE` 型で時刻を持たないため、`BETWEEN` で両端の日付をそのまま含められます。時刻を持つ `TIMESTAMP` 型に同じ書き方をすると終了日が落ちます（問題 14 で扱います）。

---

## 問題 9: 特定のカテゴリに属さない商品の在庫数を調整する
- **目的**: `NOT IN` 演算子を使用して、指定した複数の条件に合致「しない」行を更新対象とする。

### 問題:
`products_mst` テーブルで、カテゴリが **'Electronics' と 'Books' 以外** の商品の在庫数(`stock_quantity`)を、現在の値から **10個 増加** させてください。

> **注意**: このSQLはデータを変更します。**`BEGIN;` … `ROLLBACK;` で囲んで実行してください**（ここで変更される在庫数は後続の章の問題でも使用します）。

### 解答:
```sql
BEGIN;

UPDATE products_mst
SET stock_quantity = stock_quantity + 10
WHERE category NOT IN ('Electronics', 'Books');

ROLLBACK;   -- 加算した在庫を確定させずに捨てる
```

### 期待結果:
更新対象は **13 件**（Food 4件・Home & Kitchen 3件・Stationery 3件・Toys 3件）です。

### 解説:
`NOT IN ('Electronics', 'Books')` は「リストのどれとも一致しない」という条件で、`category <> 'Electronics' AND category <> 'Books'` と同じ意味です。`UPDATE` は `WHERE` を書き忘れると全行が更新されるため、先に同じ `WHERE` で `SELECT` して対象件数を確かめてから実行するのが実務の作法です。
なおこの `UPDATE` は Toys の3商品（`product_id` = 17・18・23）の在庫数を **0 → 10** に変えてしまいます。この3件が在庫0であることは [[00_SQL研修/02_問題/07_group byと集計関数|07章]] 問題 15(2)「全商品が欠品しているカテゴリ」の前提なので、`ROLLBACK` を忘れないでください。

---

## 問題 10: 特定の顧客グループの登録日を今日の最新日付に更新する
- **目的**: 特定の ID リストを `IN` 句で指定し、日付型カラムをシステム日付関数（`CURRENT_DATE`）で更新する。

### 問題:
`customers_mst` テーブルで、**customer_id が 2, 5, 7** の顧客の登録日(`created_date`)を、**今日の最新日付** に更新してください。

> **注意**: このSQLはデータを変更します。**`BEGIN;` … `ROLLBACK;` で囲んで実行してください。**

### 解答:
```sql
BEGIN;

UPDATE customers_mst
SET created_date = CURRENT_DATE
WHERE customer_id IN (2, 5, 7);

ROLLBACK;   -- 書き換えた登録日を確定させずに捨てる
```

### 解説:
`CURRENT_DATE` は実行した日の日付を返すため、実行するたびに入る値が変わります。この更新は `customer_id` = 5・7 の登録日も書き換えるので、戻さないまま進めると問題 4・問題 8 の結果が変わってしまいます。`ROLLBACK` を忘れないでください。

---

## 問題 11: 特定のキーワードを含む商品の価格を再設定する
- **目的**: `LIKE` 演算子を `WHERE` 句で使用して、文字列の部分一致で更新対象を絞り込む。

### 問題:
`products_mst` テーブルで、商品名に **「コーヒー」または「はちみつ」** という文字列が含まれる商品の価格を、一律 **1,500.00 円** に更新してください。

> **注意**: このSQLはデータを変更します。**`BEGIN;` … `ROLLBACK;` で囲んで実行してください。**

### 解答:
```sql
BEGIN;

UPDATE products_mst
SET price = 1500.00
WHERE product_name LIKE '%コーヒー%'
   OR product_name LIKE '%はちみつ%';

ROLLBACK;   -- 書き換えた価格を確定させずに捨てる
```

### 期待結果:
更新対象は **3 件**（`product_id` = 6「オーガニックコーヒー豆」・15「国産はちみつ」・20「 国産はちみつ 」）です。

### 解説:
`WHERE product_name LIKE '%コーヒー%' OR '%はちみつ%'` と書くのは間違いです。`OR` の後ろにも「列 演算子 値」の形をした**完全な条件式**を書く必要があります。

---

## 問題 12: 特定の商品名パターンに合致する商品を削除する
- **目的**: `LIKE` 演算子を `WHERE` 句で使用して、文字列の部分一致で削除対象を絞り込む。

### 問題:
`products_mst` テーブルから、商品名に **「充電器」** という文字列が含まれる商品を全て削除してください。

※なお、外部キー制約がある場合、本来は子テーブルから削除する必要がありますが、ここでは `WHERE` 句の書き方の学習として、商品テーブルに対する削除文のみ記述してください。
書けたら **実際に実行して、どうなるかを確認してください。**

> **注意**: このSQLはデータを変更します。**`BEGIN;` … `ROLLBACK;` で囲んで実行してください。** 実行結果は解答に記載しています。

### 解答:
```sql
DELETE FROM products_mst
WHERE product_name LIKE '%充電器%';

-- 実行結果: 1件も削除されず、次のエラーになる
-- ERROR:  update or delete on table "products_mst" violates foreign key constraint
--         "order_details_trn_product_id_fkey" on table "order_details_trn"
-- DETAIL:  Key (product_id)=(8) is still referenced from table "order_details_trn".
```

**正しい削除手順** ―― 実行すると注文明細が2行消えるので、`BEGIN;` … `ROLLBACK;` で囲みます。
```sql
BEGIN;

-- 1. 先に子テーブル（注文明細）から該当商品の行を削除する
DELETE FROM order_details_trn
WHERE product_id = 8;

-- 2. そのうえで親テーブル（商品マスタ）から削除する
DELETE FROM products_mst
WHERE product_name LIKE '%充電器%';

ROLLBACK;   -- 削除を確定させずに捨てる（商品23件・明細28件に戻る）
```

### 期待結果:
条件に合う商品は `product_id = 8`「USB 充電器」の **1件だけ** ですが、この商品は `order_details_trn` から **2行（order_id = 3 と 17）参照されている** ため、上記のとおり **必ず外部キー制約違反でエラーになり、1件も削除されません**。

### 解説:
参照されている親行は削除できない、というのが外部キー制約の役割そのもの（データベースが「注文明細の指す商品が存在しない」状態を防いでいる）です。実務では物理削除ではなく `deleted_at` を立てる論理削除にするのが一般的で、このテーブルにも `deleted_at` 列が用意されています。

---

## 追加課題（ここから先は任意）

**問題 12 まで**が必須です。ここから先は、早く終わった人・もっと解きたい人向けです。

---

## 問題 13: LIKE の2大落とし穴（大文字小文字・ワイルドカード文字）
- **目的**: `LIKE` が大文字小文字を区別すること、`%` や `_` そのものを検索するにはエスケープが必要であることを実データで確認し、回避策（`ILIKE` / `UPPER` / `ESCAPE`）を書けるようにする。

### 問題:
商品検索機能を実装するにあたり、`products_mst` テーブルで `LIKE` の挙動を確認します。

**(1)** 商品名に `SQL` を含む商品を `LIKE '%SQL%'` で検索してください。何件返りますか。また、その結果から **商品マスタにどんな問題があるか** を指摘してください。

**(2)** 同じ検索を小文字で `LIKE '%sql%'` と書くと何件返りますか。大文字・小文字を区別せずに検索する方法を **2通り** 書いてください。

**(3)** 商品説明(`memo`)に `%` という記号そのものが含まれる商品を探したいと考え、`memo LIKE '%%%'` と書きました。これは何件返りますか。なぜそうなるのか説明してください。

**(4)** (3) が正しく1件だけ返るように修正してください。

> **注意**: 本問はすべて `SELECT` のみで、データを変更しません。

### 解答:
```sql
-- (1) 大文字の SQL で検索 → 2件
SELECT product_id, product_name
FROM products_mst
WHERE product_name LIKE '%SQL%';

-- (1) の指摘
-- product_id=2 と product_id=19 がどちらも 'SQL 入門' で、同じ商品名が二重に登録されている。
-- product_name に UNIQUE 制約が無いため、重複登録を防げていない。

-- (2) 小文字の sql で検索 → 0件（LIKE は大文字小文字を区別する）
SELECT product_id, product_name
FROM products_mst
WHERE product_name LIKE '%sql%';

-- (2) 方法1: ILIKE を使う（PostgreSQL 独自）→ 2件
SELECT product_id, product_name
FROM products_mst
WHERE product_name ILIKE '%sql%';

-- (2) 方法2: UPPER で大文字に揃えてから比較する（移植性が高い）→ 2件
SELECT product_id, product_name
FROM products_mst
WHERE UPPER(product_name) LIKE UPPER('%sql%');

-- (3) memo LIKE '%%%' → 16件
-- 3つの % がすべてワイルドカードとして解釈されるため、
-- 「任意の文字列 + 任意の文字列 + 任意の文字列」＝ 実質「何でもよい」という条件になる。
-- 結果として memo が NULL でない全商品（16件）が返る。
SELECT COUNT(*)
FROM products_mst
WHERE memo LIKE '%%%';

-- (4) % をエスケープして「記号そのもの」を探す → 1件
SELECT product_id, product_name, memo
FROM products_mst
WHERE memo LIKE '%\%%';
```

**別解: ESCAPE 句で任意のエスケープ文字を指定する**
```sql
SELECT product_id, product_name, memo
FROM products_mst
WHERE memo LIKE '%!%%' ESCAPE '!';
```

### 期待結果:

(1) `LIKE '%SQL%'` ―― 2件

| product_id | product_name |
| ---: | :--- |
| 2 | SQL 入門 |
| 19 | SQL 入門 |

(2) `LIKE '%sql%'` は **0件**。`ILIKE '%sql%'` / `UPPER(product_name) LIKE UPPER('%sql%')` はどちらも **2件**（(1) と同じ結果）。

(3) `memo LIKE '%%%'` ―― **16件**（`memo` が NULL でない全商品。商品総数23件のうち7件は `memo` が NULL）

(4) エスケープ後 ―― 1件

| product_id | product_name | memo |
| ---: | :--- | :--- |
| 15 | 国産はちみつ | 100%純粋なはちみつ |

### 解説:
`LIKE` は大文字小文字を区別するため、検索機能をそのまま `LIKE` で実装すると「`sql` で検索しても商品が出てこない」というクレームになります（PostgreSQL なら `ILIKE`、他DBMSへの移植性を重視するなら `UPPER()` で揃える）。`%` と `_` はパターン中では常にワイルドカードなので、記号そのものを探すにはエスケープが必須です。ユーザーの入力値をそのまま `LIKE` に渡すと `%` 1文字で全件がヒットし検索が実質無効になるため、アプリ側で入力値のエスケープが必要になります。

---

## 問題 14: TIMESTAMP に BETWEEN を使うと終了日が漏れる
- **目的**: 日時型(`TIMESTAMPTZ`)に対する `BETWEEN` は終端が `00:00:00` として解釈されるため最終日のデータが落ちることを理解し、`>= 開始日 AND < 翌日` という半開区間で書けるようにする。

### 問題:
「**2023年9月15日から9月20日までの間** に販売終了になった商品と、退会した顧客を一覧にしてほしい」と依頼されました。

**(1)** `products_mst` から、`deleted_at` が上記の期間に入る商品を `BETWEEN` を使って抽出してください。何件返りますか。

**(2)** 同じ条件で `customers_mst` から退会した顧客を抽出してください。何件返りますか。

**(3)** 商品と顧客で結果が食い違います。それぞれの `deleted_at` に実際にどんな値が入っているかを確認し、原因を説明してください。

**(4)** 商品・顧客とも正しく1件ずつ返るように、両方のSQLを修正してください。

> **注意**: 本問はすべて `SELECT` のみで、データを変更しません。

### 解答:
```sql
-- (1) 商品: BETWEEN で抽出 → 0件（本来は product_id=11 が該当するはず）
SELECT product_id, product_name, deleted_at
FROM products_mst
WHERE deleted_at BETWEEN '2023-09-15' AND '2023-09-20';

-- (2) 顧客: 同じ条件で抽出 → 1件（customer_id=4）
SELECT customer_id, customer_name, deleted_at
FROM customers_mst
WHERE deleted_at BETWEEN '2023-09-15' AND '2023-09-20';

-- (3) 実際に入っている値を確認する（2本に分けて実行する）
SELECT product_id, product_name, deleted_at
FROM products_mst
WHERE deleted_at IS NOT NULL;

SELECT customer_id, customer_name, deleted_at
FROM customers_mst
WHERE deleted_at IS NOT NULL;

-- (3) の説明
-- product_id=11（ゲーミングマウス）の deleted_at = 2023-09-20 18:00:00+09（終了日当日の18時）
-- customer_id=4（山田 恵美）  の deleted_at = 2023-09-15 10:00:00+09（開始日当日の10時）
--
-- BETWEEN '2023-09-15' AND '2023-09-20' は
--   deleted_at >= '2023-09-15 00:00:00' AND deleted_at <= '2023-09-20 00:00:00'
-- と同じ意味になる。時刻を省略した日付リテラルは 00:00:00 と解釈されるため、
-- 終了日 9/20 は「9/20 の 0時ちょうど」までしか含まれず、9/20 の 18時が範囲外になって落ちる。
-- 顧客側が拾えたのは、たまたま開始日側の値だったため。

-- (4) 半開区間（>= 開始日 AND < 翌日）で書き直す → 商品1件・顧客1件
SELECT product_id, product_name, deleted_at
FROM products_mst
WHERE deleted_at >= '2023-09-15'
  AND deleted_at <  '2023-09-21';

SELECT customer_id, customer_name, deleted_at
FROM customers_mst
WHERE deleted_at >= '2023-09-15'
  AND deleted_at <  '2023-09-21';
```

### 期待結果:

(1) 商品を `BETWEEN` で抽出 ―― **0件**

(2) 顧客を `BETWEEN` で抽出 ―― 1件

| customer_id | customer_name | deleted_at |
| ---: | :--- | :--- |
| 4 | 山田 恵美 | 2023-09-15 10:00:00+09 |

(3) `deleted_at` に実際に入っている値

| テーブル | ID | 名前 | deleted_at |
| :--- | ---: | :--- | :--- |
| products_mst | 11 | ゲーミングマウス | 2023-09-20 18:00:00+09 |
| customers_mst | 4 | 山田 恵美 | 2023-09-15 10:00:00+09 |

(4) 半開区間に修正後 ―― 商品1件・顧客1件

| product_id | product_name | deleted_at |
| ---: | :--- | :--- |
| 11 | ゲーミングマウス | 2023-09-20 18:00:00+09 |

| customer_id | customer_name | deleted_at |
| ---: | :--- | :--- |
| 4 | 山田 恵美 | 2023-09-15 10:00:00+09 |

### 解説:
`BETWEEN A AND B` は `>= A AND <= B` と同じで、時刻を省略した日付リテラルは `00:00:00` と解釈されるため、日時型に `BETWEEN` を使うと **終了日の 00:00:00 より後のデータが丸ごと落ちます**（問題 8 で `created_date` に `BETWEEN` を使えたのは `DATE` 型で時刻を持たないから）。`TIMESTAMP` / `TIMESTAMPTZ` に対する期間指定は `>= 開始日 AND < 翌日` の半開区間で書くのが定石です。`<= '2023-09-20 23:59:59'` と書く回避策も見かけますが、秒未満の値が落ちるうえ精度の違うDBMSへ移すと壊れるため、半開区間の方が安全です。

---

## 問題 15: LIMIT / OFFSET のページ送りで行が重複・欠落する
- **目的**: `ORDER BY` のキーが一意でないと `LIMIT` / `OFFSET` によるページ送りで同じ行が2回出たり抜けたりすることを理解し、タイブレークに主キーを加える対処を身につける。

### 問題:
商品一覧画面を「**価格の安い順・1ページ3件**」でページ送りします。対象は **販売中の商品（`deleted_at` が NULL）** のみです。

**(1)** `ORDER BY price` だけを指定して、1ページ目（1〜3件目）と2ページ目（4〜6件目）をそれぞれ取得してください。

**(2)** 1ページ目の3件目と2ページ目の1件目は同じ価格です。商品マスタにこの価格の商品は何件あり、その `product_id` は何番でしょうか。

**(3)** このページ送りには「**同じ商品が両方のページに出る**」または「**どちらのページにも出ない**」という不具合が潜んでいます。なぜそうなるのかを説明し、正しくページ送りできるようにSQLを修正してください。

> **注意**: 本問はすべて `SELECT` のみで、データを変更しません。

### 解答:
```sql
-- (1) ORDER BY price だけでページ送りする
-- 1ページ目
SELECT product_id, product_name, price
FROM products_mst
WHERE deleted_at IS NULL
ORDER BY price
LIMIT 3 OFFSET 0;

-- 2ページ目
SELECT product_id, product_name, price
FROM products_mst
WHERE deleted_at IS NULL
ORDER BY price
LIMIT 3 OFFSET 3;

-- (2)
-- 1200.00 円の商品は product_id=15「国産はちみつ」と
-- product_id=20「 国産はちみつ 」（前後に半角スペースがある重複登録）の2件。

-- (3) の説明
-- LIMIT / OFFSET は「並べ終わった結果の何件目から何件を切り出すか」でしかないため、
-- 並び順が一意に決まらなければ、切り出される行も決まらない。
-- price が同値の 15 と 20 はどちらが先に来るか保証されず、
-- ページごとに実行される別々のSQLの間で順序が入れ替わりうる。
-- 実際にこの環境では product_id=15 が1ページ目にも2ページ目にも現れ、
-- product_id=20 はどちらのページにも現れない（＝重複と欠落が同時に発生している）。

-- (3) 修正: ORDER BY の末尾に主キーを足して並び順を一意に決める
-- 1ページ目
SELECT product_id, product_name, price
FROM products_mst
WHERE deleted_at IS NULL
ORDER BY price ASC, product_id ASC
LIMIT 3 OFFSET 0;

-- 2ページ目
SELECT product_id, product_name, price
FROM products_mst
WHERE deleted_at IS NULL
ORDER BY price ASC, product_id ASC
LIMIT 3 OFFSET 3;
```

### 期待結果:

(1) `ORDER BY price` だけの場合 ―― 壊れたページ送り

| ページ | product_id | product_name | price |
| :--- | ---: | :--- | ---: |
| 1ページ目 | 21 | A4 ノート 5冊セット | 750.00 |
| 1ページ目 | 22 | 蛍光マーカー 6色 | 980.00 |
| 1ページ目 | **15** | 国産はちみつ | 1200.00 |
| 2ページ目 | **15** | 国産はちみつ | 1200.00 |
| 2ページ目 | 8 | USB 充電器 | 1500.00 |
| 2ページ目 | 6 | オーガニックコーヒー豆 | 1800.00 |

(3) `ORDER BY price ASC, product_id ASC` に修正した場合

| ページ | product_id | product_name | price |
| :--- | ---: | :--- | ---: |
| 1ページ目 | 21 | A4 ノート 5冊セット | 750.00 |
| 1ページ目 | 22 | 蛍光マーカー 6色 | 980.00 |
| 1ページ目 | 15 | 国産はちみつ | 1200.00 |
| 2ページ目 | 20 |  国産はちみつ  | 1200.00 |
| 2ページ目 | 8 | USB 充電器 | 1500.00 |
| 2ページ目 | 6 | オーガニックコーヒー豆 | 1800.00 |

### 解説:
`LIMIT` / `OFFSET` は「並べ終わった結果の何件目から何件」を切り出すだけなので、`ORDER BY` で並び順が一意に決まらなければ取り出される行も決まりません。販売中の商品には 1200円（15 と 20 の表記ゆれ重複）・1800円（13 と 6）・2500円（2 と 19 の完全重複）という同価格ペアが3組あり、境目にこれが来ると重複表示や取りこぼしが起きます。対策は `ORDER BY` の末尾に主キーなど一意な列を必ず足してタイブレークすることです。

> **⚠️ 講師向けの注意**: (1) の「同じ行が両ページに出る」結果は実行計画に依存するため、環境やデータ量によっては再現しない（たまたま正しく見える）ことがあります。**再現しなくても不具合が無いわけではない**という点が本問の要点なので、その場合は「順序が保証されていない＝いつ壊れてもおかしくない」ことを (2) の同価格ペアから説明してください。
