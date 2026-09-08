# 02章 演習 解答：SELECT文

**PostgreSQL 17 で実際に動かした結果を載せています。** 使用するテーブルは `customers_mst` / `products_mst` です。この章は `SELECT` だけでデータを変更しないので、リセットは不要です。

---

## 問題 1: 全ての顧客情報を取得する
- **目的**: テーブルから全ての行と列を取得する `SELECT *` の基本的な使い方を理解する。

### 問題:
`customers_mst` テーブルに登録されている全ての顧客の情報を取得してください。

### 解答:
```sql
SELECT *
FROM customers_mst;
```

---

## 問題 2: 特定の商品情報のみを取得する
- **目的**: 特定の列だけを選択して取得する `SELECT 列名` の基本的な使い方を理解する。

### 問題:
`products_mst` テーブルから、商品の名前(`product_name`)と価格(`price`)だけを取得してください。

### 解答:
```sql
SELECT product_name, price
FROM products_mst;
```

---

## 問題 3: 高価格な商品を絞り込む
- **目的**: `WHERE` 句と比較演算子(`>`)を使用して、条件に合致するデータを絞り込む方法を理解する。

### 問題:
`products_mst` テーブルから、価格が 10,000 円より高い商品の全ての情報を取得してください。

### 解答:
```sql
SELECT *
FROM products_mst
WHERE price > 10000;
```

---

## 問題 4: 特定のカテゴリの商品を検索する
- **目的**: `WHERE` 句と等号演算子(`=`)を使用して、特定の文字列に一致するデータを絞り込む方法を理解する。

### 問題:
`products_mst` テーブルから、カテゴリ(`category`)が 'Electronics' の商品の、商品名と価格を取得してください。

### 解答:
```sql
SELECT product_name, price
FROM products_mst
WHERE category = 'Electronics';
```

---

## 問題 5: 商品を価格が高い順に並べる
- **目的**: `ORDER BY` 句と `DESC` を使用して、結果を降順に並び替える方法を理解する。

### 問題:
`products_mst` テーブルから、全ての商品の情報を取得し、価格が高い順に並び替えてください。

### 解答:
```sql
SELECT *
FROM products_mst
ORDER BY price DESC;
```

---

## 問題 6: 在庫数が少ない商品を特定する
- **目的**: `WHERE` 句と比較演算子(`<`)、および `ORDER BY` 句を組み合わせて、実用的な絞り込みと並び替えを行う。

### 問題:
`products_mst` テーブルから、在庫数(`stock_quantity`)が 100 個未満の商品を、在庫数が少ない順に（昇順で）表示してください。

### 解答:
```sql
SELECT *
FROM products_mst
WHERE stock_quantity < 100
ORDER BY stock_quantity ASC; -- ASC はデフォルトなので省略しても OK
```

---

## 問題 7: メモが登録されていない商品を見つける (IS NULL)
- **目的**: NULL 値の特殊な扱いや `IS NULL` 演算子の重要性を理解する。

### 問題:
`products_mst` テーブルから、メモ(`memo`)が登録されていない（NULL である）商品の商品名とカテゴリを取得してください。

### 解答:
```sql
SELECT product_name, category
FROM products_mst
WHERE memo IS NULL;
```

---

## 問題 8: メモが登録されている商品を見つける (IS NOT NULL)
- **目的**: `IS NOT NULL` 演算子の使い方を理解する。

### 問題:
`products_mst` テーブルから、メモ(`memo`)が登録されている（NULL ではない）商品の商品名とメモを取得してください。

### 解答:
```sql
SELECT product_name, memo
FROM products_mst
WHERE memo IS NOT NULL;
```

---

## 問題 9: 複合条件と複数列での並び替え
- **目的**: 複数の論理演算子(`AND`, `OR`)と複数列での並び替えを組み合わせた複雑なクエリの作成能力を養う。

### 問題:
`products_mst` テーブルから、以下の条件のいずれかに合致する商品を取得してください。
1. カテゴリが 'Electronics' **かつ** 在庫数が 100 個以上
2. カテゴリが 'Home & Kitchen' **かつ** 価格が 5,000 円以下

また、結果は**カテゴリ名で昇順**、次に**価格で降順**に並び替えてください。

### 解答:
```sql
SELECT *
FROM products_mst
WHERE (category = 'Electronics' AND stock_quantity >= 100)
   OR (category = 'Home & Kitchen' AND price <= 5000)
ORDER BY category ASC, price DESC;
```

---

## 追加課題（ここから先は任意）

**問題 9 まで**が必須です。ここから先は、早く終わった人・もっと解きたい人向けです。

---

## 問題 10: 「今生きているデータ」だけを取り出す
- **目的**: 論理削除列(`deleted_at`)を `WHERE` に必ず加える実務の作法を身につけ、あわせて `= NULL` が常に0件になる理由（NULL は等価比較できない）を理解する。

### 問題:
`products_mst` テーブルには、販売終了した商品に販売終了日時を記録する `deleted_at` 列があります（販売中の商品は NULL）。以下を順に実行してください。

1. いま出荷できる商品（**販売終了しておらず、在庫が1個以上ある**商品）の `product_id` / `category` / `product_name` / `stock_quantity` を、在庫数の少ない順に取得してください。
2. 1 のSQLから `deleted_at` の条件**だけ**を外すと、結果は何件増えますか。増えたのはどの商品ですか。
3. 1 のSQLで `deleted_at IS NULL` の代わりに `deleted_at = NULL` と書くと、結果は何件になりますか。またそれはなぜですか。

### 解答:
```sql
-- 1. いま出荷できる商品（18件）
SELECT product_id, category, product_name, stock_quantity
FROM products_mst
WHERE deleted_at IS NULL
  AND stock_quantity >= 1
ORDER BY stock_quantity ASC;

-- 2. deleted_at の条件を外すと 19件（1件増える）
SELECT product_id, category, product_name, stock_quantity
FROM products_mst
WHERE stock_quantity >= 1
ORDER BY stock_quantity ASC;

-- 3. = NULL と書くとエラーにならず 0件
SELECT product_id, category, product_name, stock_quantity
FROM products_mst
WHERE deleted_at = NULL
  AND stock_quantity >= 1
ORDER BY stock_quantity ASC;
```

### 期待結果:
1 の結果（18件・在庫数の少ない上位5件）

| product_id | category | product_name | stock_quantity |
| ---: | :--- | :--- | ---: |
| 20 | Food | ` 国産はちみつ ` | 30 |
| 19 | Books | SQL 入門 | 60 |
| 3 | Home & Kitchen | 電気ケトル | 80 |
| 9 | Books | データ分析の基礎 | 90 |
| 4 | Electronics | スマートウォッチ | 100 |

### 解説:
全23件から販売終了の1件と在庫0の4件(`product_id` = 7, 17, 18, 23)が落ちて18件になり、2 で `deleted_at` の条件を外すと販売終了済みの `product_id` = 11「ゲーミングマウス」（在庫70・2023-09-20 販売終了）が混ざって19件になります。3 の `deleted_at = NULL` はエラーにならず静かに0件を返すのが最も危険で、NULL は等価比較すると結果が TRUE でも FALSE でもなく NULL（不明）になるため `WHERE` を1行も通過できません。NULL の判定には必ず `IS NULL` / `IS NOT NULL` を使ってください。

---

## 問題 11: 「〜ではない」で絞ったら件数が合わない
- **目的**: `<>`（等しくない）で除外条件を書くと NULL の行まで一緒に消えるという三値論理の落とし穴を、実データで体験して回避策を書けるようにする。

### 問題:
`products_mst` の `Books` カテゴリには、誤って二重登録された商品が1件あります（`memo` が `'改訂版として誤って二重登録'` の `product_id = 19`）。以下を順に実行してください。

1. `Books` カテゴリの商品が全部で何件あるかを確認してください。
2. 「誤登録の1件を除いた Books 一覧」のつもりで、`WHERE category = 'Books' AND memo <> '改訂版として誤って二重登録'` という条件で商品を取得してください。何件返りますか。
3. 2 の結果からは、本来出るはずの商品が1件消えています。どの商品が、なぜ消えたのかを説明したうえで、正しく4件返るSQLに直してください。

### 解答:
```sql
-- 1. Books カテゴリの一覧（5件）
SELECT product_id, product_name, memo
FROM products_mst
WHERE category = 'Books'
ORDER BY product_id;

-- 2. <> だけで除外すると 3件しか返らない（1件多く消えている）
SELECT product_id, product_name, memo
FROM products_mst
WHERE category = 'Books'
  AND memo <> '改訂版として誤って二重登録'
ORDER BY product_id;

-- 3. NULL の行を明示的に拾い直すと正しく 4件
SELECT product_id, product_name, memo
FROM products_mst
WHERE category = 'Books'
  AND (memo <> '改訂版として誤って二重登録' OR memo IS NULL)
ORDER BY product_id;
```

### 期待結果:
3 の結果（4件）

| product_id | product_name | memo |
| ---: | :--- | :--- |
| 2 | SQL 入門 | (NULL) |
| 5 | Python プログラミング | 初心者向けの解説書 |
| 9 | データ分析の基礎 | 統計学の基本から学習 |
| 13 | 自己啓発の法則 | 成功へのヒント |

### 解説:
2 で消えたのは `product_id` = 2「SQL 入門」で、この行は `memo` が NULL のため `NULL <> '改訂版として誤って二重登録'` が FALSE ではなく NULL（不明）と評価され、TRUE の行しか通さない `WHERE` を抜けられません。「〜ではない」で絞るときは対象列が NULL を許すかを必ず確認し、必要なら `OR 列名 IS NULL` を足します。同じ落とし穴は `NOT IN`（06章）でも起きます。

---

## 問題 12: 在庫金額を計算して並べる
- **目的**: `SELECT` 句の中で列同士の四則演算を行い、`AS` で付けた別名をそのまま `ORDER BY` のキーに使えることを理解する。

### 問題:
`products_mst` テーブルから、**販売中の商品**（`deleted_at` が NULL の商品）について、`product_id` / `category` / `product_name` / `price` / `stock_quantity` に加えて、`price * stock_quantity`（在庫金額）を `inventory_value` という別名で表示してください。

並び順は `inventory_value` の大きい順とし、同額の場合は `product_id` の昇順としてください。

### 解答:
```sql
SELECT
    product_id,
    category,
    product_name,
    price,
    stock_quantity,
    price * stock_quantity AS inventory_value
FROM
    products_mst
WHERE
    deleted_at IS NULL
ORDER BY
    inventory_value DESC, product_id ASC;
```

### 期待結果:
（22件・上位5件）

| product_id | category | product_name | price | stock_quantity | inventory_value |
| ---: | :--- | :--- | ---: | ---: | ---: |
| 4 | Electronics | スマートウォッチ | 29800.00 | 100 | 2980000.00 |
| 1 | Electronics | ワイヤレスイヤホン | 12800.00 | 150 | 1920000.00 |
| 14 | Electronics | ポータブルバッテリー | 3980.00 | 220 | 875600.00 |
| 16 | Stationery | 多機能ボールペン | 2800.00 | 300 | 840000.00 |
| 8 | Electronics | USB 充電器 | 1500.00 | 500 | 750000.00 |

### 解説:
`SELECT` 句には列名だけでなく `price * stock_quantity` のような計算式も書け、その結果に `AS` で別名を付けられます。PostgreSQL では `ORDER BY` に `SELECT` 句で付けた別名 `inventory_value` をそのまま指定できます。末尾に `0.00` が4件並ぶのは在庫切れ(`stock_quantity` = 0)のためで、`ORDER BY` の第2キーに `product_id` を足しているのは同額のときの並び順を一意に固定するためです。
