# 18章 演習 解答：window関数

**PostgreSQL 17 で実際に動かした結果を載せています。** 08章で作成したテーブルをそのまま使います。この章は `SELECT` だけでデータを変更しないので、リセットは不要です。

---

## 問題 1: 各顧客の最初と最新の注文日
- **目的**: `FIRST_VALUE` / `LAST_VALUE` の特性と、Windowフレームの挙動を理解する。

### 問題:
各顧客について、最初の注文日と最新の注文日を特定し、それぞれの注文と共に表示してください。

### 解答:
```sql
SELECT
    customer_id,
    order_id,
    order_date,
    -- 顧客ごとの最初の注文日
    FIRST_VALUE(order_date) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
    ) AS first_order_date,
    -- 顧客ごとの最新の注文日（フレーム指定が必要）
    LAST_VALUE(order_date) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC 
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS latest_order_date
FROM orders
ORDER BY customer_id, order_date;
```

### 解説:
*   **FIRST_VALUE:** ウィンドウ内の最初の値を取得します。
*   **LAST_VALUEの罠:** デフォルトのウィンドウフレームは「先頭から現在の行まで」です。そのため、単に `ORDER BY` を書くだけだと「現在の行」が常に最後になってしまい、期待した最新日が取れません。
*   **ROWS BETWEEN...:** 最新値を取得するには、`UNBOUNDED FOLLOWING`（ウィンドウの最後まで）を指定して、現在の行以降も検索対象に含める必要があります。
*   **別解:** 単に日付が欲しいだけであれば、`MIN(order_date) OVER(PARTITION BY customer_id)` でも同様の結果が得られます（集約関数のWindow関数利用）。

---

## 問題 2: 各顧客の注文ごとの累計注文額
- **目的**: `SUM()` をWindow関数として使い、時系列の累計（ランニングトータル）を計算する。

### 問題:
各顧客について、注文日毎、注文日順に累計注文額（OrderItems テーブルの quantity_Products.price の合計）を計算してください。

### 解答:
```sql
WITH order_amounts AS (
    -- 1. まず注文単位の合計金額を算出
    SELECT
        o.customer_id,
        o.order_id,
        o.order_date,
        SUM(oi.quantity * p.price) AS amount
    FROM orders o
    JOIN orderitems oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY o.customer_id, o.order_id, o.order_date
)
SELECT
    customer_id,
    order_id,
    order_date,
    amount AS order_amount,
    -- 2. 顧客ごとに日付順で累計を計算
    SUM(amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC, order_id ASC
    ) AS cumulative_amount
FROM order_amounts
ORDER BY customer_id, order_date;
```

### 解説:
*   **集計の二段階化:** `orderitems` には1つの注文で複数行あるため、そのままWindow関数を使うと「行ごとの累計」になってしまいます。「注文ごとの累計」にするため、一度CTE（WITH句）で注文単位にまとめています。
*   **暗黙のフレーム:** `ORDER BY` を指定したWindow関数（SUMなど）は、デフォルトで「先頭から現在の行まで（ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW）」の集計となります。これがそのまま累計のロジックになります。

---

## 問題 3: カテゴリ内の価格ランキング（3種）
- **目的**: `ROW_NUMBER`, `RANK`, `DENSE_RANK` の違いを明確に使い分ける。

### 問題:
各商品カテゴリ内で、価格の高い順に商品のランキングを付けてください。

### 解答:
```sql
SELECT
    cat.category_name,
    p.product_name,
    p.price,
    -- 1. 連続番号 (1, 2, 3...)
    ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS row_num,
    -- 2. 同率あり・後続スキップ (1, 2, 2, 4...)
    RANK() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rank_num,
    -- 3. 同率あり・後続連続 (1, 2, 2, 3...)
    DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS dense_rank_num
FROM products p
JOIN categories cat ON p.category_id = cat.category_id
ORDER BY cat.category_name, p.price DESC;
```

### 解説:
*   **ROW_NUMBER:** 値が同じでも必ず一意の番号を振ります。ページネーションなどに適しています。
*   **RANK:** オリンピック方式です。2位が2人いたら次は4位になります。
*   **DENSE_RANK:** 2位が2人いても次は3位になります。
*   実務では「各カテゴリの最高値の商品だけ欲しい」といった場合に、これらをサブクエリ内で使い、外側で `WHERE rank_num = 1` と絞り込む手法（Top-N分析）が頻出します。

---

## 問題 4: 各顧客の移動平均（直近3回分）
- **目的**: `ROWS BETWEEN` を活用して「移動平均（Moving Average）」を算出する。

### 問題:
各顧客について、注文日順に、現在行とその過去 2 回分の注文（合計 3 回分）の合計金額の移動平均を計算してください。

### 解答:

```sql
-- 案1: 素直に ROWS BETWEEN 2 PRECEDING AND CURRENT ROW を書く
WITH daily_order_totals AS (
    SELECT
        o.customer_id,
        o.order_date,
        o.order_id,
        SUM(oi.quantity * p.price) AS total_amount
    FROM orders o
    JOIN orderitems oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY o.customer_id, o.order_date, o.order_id
)
SELECT
    customer_id,
    order_date,
    total_amount,
    -- 自分自身を含めた過去3回分の平均を算出
    AVG(total_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC, order_id ASC
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3_orders
FROM daily_order_totals;
```

案1には落とし穴があります。**3件に満たない顧客にも値が出てしまう**（1件目は自分自身の値、2件目は2件の平均）ので、「3回分の移動平均」としては誤りです。実務ではこちらを使います。

```sql
-- 案2: 3件そろうまでは NULL にする（推奨）
WITH
	daily_order_totals AS (
		SELECT
			o.customer_id,
			o.order_date,
			o.order_id,
			SUM(oi.quantity * p.price) AS total_amount
		FROM
			orders o
			JOIN orderitems oi ON o.order_id = oi.order_id
			JOIN products p ON oi.product_id = p.product_id
		GROUP BY
			o.customer_id,
			o.order_date,
			o.order_id
	)
SELECT
	customer_id,
	order_date,
	total_amount,
	-- 自分自身を含めた過去3回分の平均を算出
	ROW_NUMBER() OVER (
		PARTITION BY
			customer_id
		ORDER BY
			order_date,
			order_id
	),
	CASE
		WHEN ROW_NUMBER() OVER (
			PARTITION BY
				customer_id
			ORDER BY
				order_date,
				order_id
		) < 3 THEN NULL
		ELSE ROUND(
			AVG(total_amount) OVER (
				PARTITION BY
					customer_id
				ORDER BY
					order_date ASC,
					order_id ASC ROWS BETWEEN 2 preceding
					AND current ROW
			),
			2
		)
	END AS moving_avg_3_orders
FROM
	daily_order_totals;
```

### 解説:
*   **ROWS BETWEEN 2 PRECEDING AND CURRENT ROW:** 「2つ前の行から現在の行まで」の計3行を計算対象に指定しています。
*   **分析の用途:** 単発の巨大な注文によるノイズを除去し、顧客の購買トレンドを滑らかに把握するために使用されます。
*   **フレームは「足りなければ足りないまま」計算する:** 1件目・2件目でもエラーにはならず、存在する行だけで平均を出します。エラーが出ないぶん誤りに気づきにくいので、案2のように `ROW_NUMBER()` で件数を数えて `NULL` に倒すのが安全です。

---

## 問題 5: 前回注文からの経過日数
- **目的**: `LAG` 関数を使って「前の行」のデータと比較する。

### 問題:
各顧客について、注文日順に、それぞれの注文がその顧客の前の注文から何日後にあったかを計算してください。最初の注文には NULL を返してください。

### 解答:
```sql
SELECT
    customer_id,
    order_id,
    order_date,
    -- 1つ前の注文日を取得
    LAG(order_date) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
    ) AS prev_order_date,
    -- PostgreSQLでは日付同士を引くと整数（日数）が返る
    order_date - LAG(order_date) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
    ) AS days_since_last_order
FROM orders
ORDER BY customer_id, order_date;
```

### 解説:
*   **LAG(カラム, オフセット):** 第2引数を省略すると「1つ前」の値を取得します。
*   **LEAD:** 逆に「1つ先」の値を取りたい場合は `LEAD` を使用します。
*   **PostgreSQLの利点:** 日付型の計算がシンプルで、`date - date` で経過日数（integer）が得られます。SQL ServerやMySQLのように特別な関数（DATEDIFF等）を覚える必要がありません。

---

## 問題 6: 全体平均との乖離（OVER()）
- **目的**: `PARTITION BY` を指定しないWindow関数で、全体統計との比較を行う。

### 問題:
各注文について、その注文の合計金額（OrderItems.quantity * Products.price の合計）と、全注文の平均合計金額との差分を計算してください。

### 解答:
```sql
WITH order_summary AS (
    SELECT order_id, SUM(quantity * price) AS amount
    FROM orderitems JOIN products USING(product_id)
    GROUP BY order_id
)
SELECT
    order_id,
    amount,
    -- 引数なしのOVER()は「全体」を意味する
    AVG(amount) OVER() AS global_avg,
    amount - AVG(amount) OVER() AS diff_from_avg
FROM order_summary
ORDER BY diff_from_avg DESC;
```

### 解説:
*   **OVER():** 括弧の中が空の場合、テーブル全体の行が1つのウィンドウになります。
*   **メリット:** 通常の集約関数で全体平均を出そうとすると、一度平均を出してからJOINするか、スカラーサブクエリを使う必要がありますが、Window関数なら1行で済みます。

---

## 問題 7: 累計購入額による顧客セグメント(NTILE)
- **目的**: `NTILE` を使ってデータを等分し、簡易的なランク付けを行う。

### 問題:
各顧客の累計注文額を算出し、その累計注文額が高い順に、全顧客を 4 つのグループ（NTILE）に分割してください。それぞれの顧客がどのグループに属するかを表示してください。

### 解答:
```sql
WITH customer_ltv AS (
    SELECT 
        customer_id, 
        SUM(quantity * price) AS total_spent
    FROM orders
    JOIN orderitems USING(order_id)
    JOIN products USING(product_id)
    GROUP BY customer_id
)
SELECT
    customer_id,
    total_spent,
    -- 購入額が多い順に並べて4つのグループに分ける
    NTILE(4) OVER(ORDER BY total_spent DESC) AS spend_quartile
FROM customer_ltv;
```

### 解説:
*   **NTILE(4):** データを4等分し、1〜4の番号を振ります。
*   **用途:** 上位25%を「優良顧客（Group 1）」、下位25%を「離脱懸念（Group 4）」とするような、四分位分析（Quartile Analysis）に非常に便利です。

---

## 問題 8: カテゴリ内の価格分布（PERCENT_RANK）
- **目的**: `PERCENT_RANK` で相対的なポジション（0〜1）を算出する。

### 問題:
各商品カテゴリ内で、商品の価格がそのカテゴリ内の他の商品と比較してどの程度のパーセンタイルに位置するかを計算してください。（PERCENT_RANK を使用）

### 解答:
```sql
SELECT
    category_id,
    product_name,
    price,
    -- カテゴリ内での価格の相対位置（パーセンタイル）
    PERCENT_RANK() OVER(
        PARTITION BY category_id 
        ORDER BY price ASC
    ) AS price_percentile
FROM products;
```

### 解説:
*   **PERCENT_RANK:** その行が「下から数えて何%の位置にいるか」を0から1の間で返します。
*   **計算式:** `(RANK - 1) / (総行数 - 1)`
*   最安値の商品なら `0`、最高値の商品なら `1` になります。商品価格がそのカテゴリの中で「高級ライン」なのか「普及ライン」なのかを判別する指標になります。