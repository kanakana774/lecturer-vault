# 07章 演習 解答：group byと集計関数

**PostgreSQL 17 で実際に動かした結果を載せています。** 使用するテーブルは02章で作成した `products_mst` / `customers_mst` / `orders_trn` / `order_details_trn` です。

---

## 準備

### 使用するテーブル
02章で作成した `products_mst` / `customers_mst` / `orders_trn` / `order_details_trn` をそのまま使います。
まだ作っていない場合は、02章の DDL スクリプト（`02_DDL（前半用）`）を実行して作成してください。

### リセット手順

**この章は全問 `SELECT` だけなのでデータは変わりません。リセットは不要です。**

---

## 問題 1: 全商品数とカテゴリ数
- **目的**: `COUNT(*)` と `COUNT(DISTINCT 列名)` を使用して、テーブルの全行数と、重複を除いたユニークな要素数をカウントする違いを理解する。

### 問題:
`products_mst` テーブルについて、以下の2つの値を算出してください。

1. **total_products**: 登録されている全商品の数
2. **unique_categories**: 登録されているユニークな（重複を除いた）カテゴリの数

### 解答:
```sql
-- 1. 全商品数
SELECT COUNT(*) AS total_products
FROM products_mst;

-- 2. ユニークなカテゴリ数
SELECT COUNT(DISTINCT category) AS unique_categories
FROM products_mst;
```

---

## 問題 2: 商品の合計価格と平均価格
- **目的**: `SUM()` と `AVG()` を使用して、数値列の合計値と平均値を算出する。

### 問題:
`products_mst` テーブルに登録されている全商品の、**価格の合計** と **平均価格** をそれぞれ算出してください。

### 解答:
```sql
SELECT
    SUM(price) AS total_price,
    AVG(price) AS average_price
FROM
    products_mst;
```

---

## 問題 3: 最も安い商品と最も高い商品の価格
- **目的**: `MIN()` と `MAX()` を使用して、列の最小値と最大値を特定する。

### 問題:
`products_mst` テーブルから、**最も安い商品の価格** と **最も高い商品の価格** をそれぞれ取得してください。

### 解答:
```sql
SELECT
    MIN(price) AS min_product_price,
    MAX(price) AS max_product_price
FROM
    products_mst;
```

---

## 問題 4: カテゴリごとの商品数と平均価格
- **目的**: `GROUP BY` 句を使用して特定の列（カテゴリ）でデータをグループ化し、グループごとに集計関数を実行する。

### 問題:
`products_mst` テーブルから、**カテゴリごと** の「商品数」と「平均価格」を算出してください。

### 解答:
```sql
SELECT
    category,
    COUNT(*) AS product_count,
    AVG(price) AS average_price
FROM
    products_mst
GROUP BY
    category;
```

---

## 問題 5: 高価格帯の商品が多いカテゴリを特定する
- **目的**: `HAVING` 句を使用して、`GROUP BY` で集計された**結果に対して**条件を指定し、フィルタリングを行う。

### 問題:
`products_mst` テーブルから、**平均価格が 5,000 円より大きい** カテゴリのみを抽出し、その「カテゴリ名」「商品数」「平均価格」を表示してください。

### 解答:
```sql
SELECT
    category,
    COUNT(*) AS product_count,
    AVG(price) AS average_price
FROM
    products_mst
GROUP BY
    category
HAVING
    AVG(price) > 5000;
```
### 解説:
集計結果（平均価格）に対する条件なので、`WHERE` ではなく `HAVING` を使います。

---

## 問題 6: 在庫が特定の数量以上の商品のカテゴリ別集計
- **目的**: `WHERE` 句（集計前の行フィルタリング）と、`GROUP BY` + `HAVING`（集計後のグループフィルタリング）の処理順序と使い分けを理解する。

### 問題:
`products_mst` テーブルから、以下の条件で集計を行ってください。

1. **集計対象**: 在庫数(`stock_quantity`)が **100 個以上** の商品のみ
2. **集計単位**: カテゴリごと
3. **表示条件**: 集計した結果、商品数が **2 つ以上** あるカテゴリのみを表示

表示項目は「カテゴリ名」と「商品数」です。

### 解答:
```sql
SELECT
    category,
    COUNT(*) AS product_count
FROM
    products_mst
WHERE
    stock_quantity >= 100 -- 1. まず、在庫数 100 個以上の商品に絞り込む (WHERE)
GROUP BY
    category
HAVING
    COUNT(*) >= 2; -- 2. その後、グループ化された結果で商品数が 2 つ以上のものを抽出 (HAVING)
```

---

## 問題 7: 注文ごとの異なる商品点数と合計購入個数
- **目的**: `COUNT(DISTINCT 列名)` と `SUM()` を組み合わせて、各グループ内でユニークな要素の数と合計を算出する。

### 問題:
`order_details_trn` テーブルから、注文ID(`order_id`)ごとに以下の2つを算出してください。

1. **異なる商品の種類数** (distinct_product_count)
2. **合計購入個数** (total_quantity_ordered)

### 解答:
```sql
SELECT
    order_id,
    COUNT(DISTINCT product_id) AS distinct_product_count,
    SUM(quantity) AS total_quantity_ordered
FROM
    order_details_trn
GROUP BY
    order_id;
```
### 解説:
このテーブルの主キーは `(order_id, product_id)` なので、1つの注文の中に同じ `product_id` が重複して登録されることは本来ありません。そのため `COUNT(*)` でも結果は同じになりますが、「商品の種類数」を数えるという意味を明確にするため `COUNT(DISTINCT ...)` を使用しています。

---

## 問題 8: 顧客の登録年ごとの顧客数
- **目的**: `EXTRACT()` 関数で日付から「年」を抽出し、その計算結果でグループ化して集計を行う。

### 問題:
`customers_mst` テーブルから、顧客の **登録年** (`created_date` の年部分) ごとに、登録された顧客の数を算出してください。
結果は年の順に並べてください。

### 解答:
```sql
SELECT
    EXTRACT(YEAR FROM created_date) AS registration_year,
    COUNT(*) AS customer_count
FROM
    customers_mst
GROUP BY
    registration_year -- PostgreSQLではSELECT句のエイリアスをGROUP BYで使用可能
ORDER BY
    registration_year;
```
### 解説:
`GROUP BY` に `SELECT` 句の別名（エイリアス）を書けるのは PostgreSQL の拡張です。標準に寄せるなら `GROUP BY EXTRACT(YEAR FROM created_date)` と式をもう一度書きます（→ [[07_集約関数]] §2-3）。

---

## 問題 9: 注文から90日後の月別集計
- **目的**: 日付の加算、`EXTRACT()` 関数、`GROUP BY` を組み合わせ、計算後の値に基づいて集計する応用力を養う。

### 問題:
`orders_trn` テーブルについて、各注文の「注文日から90日後」の日付を計算し、その **「90日後の日付」の月ごと** に、該当する注文の数を算出してください。

※ 月の取り出しには `EXTRACT(MONTH FROM ...)` を使ってください（`TO_CHAR` は使いません）。結果は月の昇順に並べてください。

### 解答:
```sql
SELECT
    EXTRACT(MONTH FROM (order_date + INTERVAL '90 days')) AS calculated_month,
    COUNT(*) AS orders_count
FROM
    orders_trn
GROUP BY
    calculated_month
ORDER BY
    calculated_month;
```

### 期待結果:
| calculated_month | orders_count |
| ---: | ---: |
| 5 | 2 |
| 6 | 1 |
| 10 | 1 |
| 11 | 10 |
| 12 | 4 |

> **⚠️ 講師向けの注意**: 注文データには2023年と2024年の両方が含まれているため、`EXTRACT(MONTH)` だけでグループ化すると **異なる年の同じ月が合算されます**（11月の10件は 2023-11 と 2024-11 の合計）。
> 設問の指示どおりなので解答としては正しいのですが、**月次集計としては壊れている**という点が重要です。この欠陥をそのまま教材にしたのが **問題17** なので、続けて出題すると効果的です。

---

## 追加課題（ここから先は任意）

**問題 9 まで**が必須です。ここから先は、早く終わった人・もっと解きたい人向けです。

---

## 問題 10: カテゴリ別の在庫評価額ランキング
- **目的**: `SUM(列 × 列)` を使い、「行ごとに計算してから集計する」という処理順序を理解する。あわせて、集計の前に論理削除された行を除外する実務の作法を身につける。

### 問題:
`products_mst` テーブルから、**カテゴリごと** の「商品数」と「在庫評価額」を算出し、**在庫評価額が高い順** に並べてください。

- **在庫評価額**: そのカテゴリが今抱えている在庫の金額。商品ごとの `価格 × 在庫数` を合計したもの（列名は `inventory_value`）
- **販売終了した商品（`deleted_at` が入っている商品）は集計に含めないこと**

### 解答:
```sql
SELECT
    category,
    COUNT(*) AS product_count,
    SUM(price * stock_quantity) AS inventory_value
FROM
    products_mst
WHERE
    deleted_at IS NULL          -- 販売終了商品を集計対象から外す
GROUP BY
    category
ORDER BY
    inventory_value DESC;
```

### 期待結果:
| category | product_count | inventory_value |
| :--- | ---: | ---: |
| Electronics | 4 | 6,525,600.00 |
| Books | 5 | 1,826,000.00 |
| Stationery | 3 | 1,626,600.00 |
| Food | 4 | 1,452,000.00 |
| Home & Kitchen | 3 | 965,000.00 |
| Toys | 3 | 0.00 |

### 解説:
`SUM(price * stock_quantity)` は「行ごとに掛け算 → 合計」の順序が重要です（`SUM(price) * SUM(stock_quantity)` は全く違う数字になる誤り）。`WHERE deleted_at IS NULL` を外すと販売終了商品が混入するため、論理削除を扱うテーブルでは集計前に必ず除外します。Toys の在庫評価額が0円なのは全商品欠品のためで、問題15(2) の伏線になっています。

---

## 問題 11: 商品マスタの整備状況レポート
- **目的**: `COUNT(*)` と `COUNT(列名)` の違いを「NULL を無視する性質」として実務に応用する。あわせて、割合を求める際の整数除算の罠を理解する。

### 問題:
`products_mst` テーブルから、**カテゴリごと** に以下の5項目を算出してください（この問題では販売終了商品も集計対象に含めます）。

1. **total**: 登録されている商品数
2. **discontinued**: 販売終了になっている商品数（`deleted_at` が入っている商品）
3. **active**: まだ販売中の商品数
4. **memo_filled**: 商品説明（`memo`）が入力済みの商品数
5. **memo_filled_rate**: `memo` の入力率（％。小数第1位まで）

※ `discontinued` と `memo_filled` は、**`WHERE` 句を使わずに** 算出してください。

### 解答:
```sql
SELECT
    category,
    COUNT(*)                     AS total,
    COUNT(deleted_at)            AS discontinued,   -- deleted_atがNULLでない件数
    COUNT(*) - COUNT(deleted_at) AS active,
    COUNT(memo)                  AS memo_filled,    -- memoがNULLでない件数
    ROUND(100.0 * COUNT(memo) / COUNT(*), 1) AS memo_filled_rate
FROM
    products_mst
GROUP BY
    category
ORDER BY
    memo_filled_rate;
```

### 期待結果:
| category | total | discontinued | active | memo_filled | memo_filled_rate |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Stationery | 3 | 0 | 3 | 1 | 33.3 |
| Food | 4 | 0 | 4 | 2 | 50.0 |
| Toys | 3 | 0 | 3 | 2 | 66.7 |
| Electronics | 5 | 1 | 4 | 4 | 80.0 |
| Books | 5 | 0 | 5 | 4 | 80.0 |
| Home & Kitchen | 3 | 0 | 3 | 3 | 100.0 |

### 解説:
`deleted_at` は削除された行だけ値が入る列なので、`COUNT(deleted_at)` がそのまま削除済み件数になります（`WHERE` を使わずに全体・削除済み・有効を1行で並べられる）。`memo_filled_rate` は `100 * COUNT(memo) / COUNT(*)` と書くと整数同士の割り算になり小数が切り捨てられるため、`100.0 *` のように分子か分母を必ず小数にします。

---

## 問題 12: 価格帯ごとの商品分布（ヒストグラム）
- **目的**: CASE 式を「表示用の列を作るもの」から「グループ化の軸そのもの」へと発展させる。

### 問題:
`products_mst` テーブルの **販売中の商品** を以下の価格帯に分類し、**価格帯ごと** の「商品数」と「平均価格（小数点以下を四捨五入）」を算出してください。
結果は価格の安い帯から順に並べてください。

| 価格帯（`price_band`） | 条件 |
| :--- | :--- |
| `1:～2,999円` | 3,000円未満 |
| `2:3,000～9,999円` | 3,000円以上 10,000円未満 |
| `3:10,000円～` | 10,000円以上 |

### 解答:
```sql
SELECT
    CASE
        WHEN price <  3000 THEN '1:～2,999円'
        WHEN price < 10000 THEN '2:3,000～9,999円'
        ELSE                    '3:10,000円～'
    END AS price_band,
    COUNT(*) AS product_count,
    ROUND(AVG(price)) AS avg_price
FROM
    products_mst
WHERE
    deleted_at IS NULL
GROUP BY
    price_band      -- PostgreSQLではSELECT句の別名をGROUP BYで使用可能
ORDER BY
    price_band;
```

### 期待結果:
| price_band | product_count | avg_price |
| :--- | ---: | ---: |
| 1:～2,999円 | 12 | 1803 |
| 2:3,000～9,999円 | 8 | 5360 |
| 3:10,000円～ | 2 | 21300 |

### 解説:
CASE式の結果はSELECT句だけでなく `GROUP BY` の軸にもできます（標準SQLでは同じCASE式を `GROUP BY` にも書く必要があります）。ラベル先頭の `1:` `2:` `3:` は、文字列としての並び順を制御するための工夫です。

---

## 問題 13: 商品名の重複チェック（マスタの名寄せ）
- **目的**: `GROUP BY` + `HAVING COUNT(*) > 1` という、実務で最も使用頻度の高い「重複検出」のパターンを習得する。あわせて、表記ゆれが単純な `GROUP BY` では検出できないことを体験する。

### 問題:

**(1)** `products_mst` テーブルに、**同じ商品名で2件以上登録されている商品** がないか調査してください。
表示項目は「商品名」「登録件数」「最小の product_id」「最大の product_id」です。

**(2)** (1) の結果には、実は取りこぼしがあります。`product_id = 15` と `product_id = 20` の商品名を確認し、**なぜ (1) では重複として検出されなかったのか** を説明してください。

**(3)** (2) の取りこぼしも検出できるように、(1) のクエリを修正してください。

### 解答:
```sql
-- (1) 完全一致の重複を検出
SELECT
    product_name,
    COUNT(*) AS cnt,
    MIN(product_id) AS min_id,
    MAX(product_id) AS max_id
FROM
    products_mst
GROUP BY
    product_name
HAVING
    COUNT(*) > 1;

-- (2)
-- product_id=15 は '国産はちみつ'
-- product_id=20 は ' 国産はちみつ '（前後に半角スペースがある）
-- GROUP BY は文字列が1文字でも違えば別グループとして扱うため、
-- 空白の有無だけで別の商品名と判定され、重複として検出されない。

-- (3) 前後の空白を取り除いてからグループ化する
SELECT
    TRIM(product_name) AS normalized_name,
    COUNT(*) AS cnt,
    MIN(product_id) AS min_id,
    MAX(product_id) AS max_id
FROM
    products_mst
GROUP BY
    TRIM(product_name)
HAVING
    COUNT(*) > 1;
```

### 期待結果:

(1) の結果 ―― 1件だけ検出される

| product_name | cnt | min_id | max_id |
| :--- | ---: | ---: | ---: |
| SQL 入門 | 2 | 2 | 19 |

(3) の結果 ―― 表記ゆれも拾えて2件になる

| normalized_name | cnt | min_id | max_id |
| :--- | ---: | ---: | ---: |
| 国産はちみつ | 2 | 15 | 20 |
| SQL 入門 | 2 | 2 | 19 |

### 解説:
`GROUP BY` + `HAVING COUNT(*) > 1` は重複検出の定型句です（この種の調査クエリは0件が正常）。ただし空白などの表記ゆれがあると別グループとして扱われ検出漏れが起きるため、(3)のように `TRIM` で正規化してからグループ化します。`MIN`/`MAX(product_id)` はどちらを残すかの判断材料です。

---

## 問題 14: リピーター顧客と休眠顧客の抽出
- **目的**: `MIN` / `MAX` を日付列に適用し、`HAVING` で集計結果を条件にする。「顧客の購買期間」という実務の指標を自力で組み立てる。

### 問題:
`orders_trn` テーブルを使って、以下の2つを算出してください。いずれも **キャンセルされた注文（`deleted_at` が入っている注文）は除外** します。

**(1) リピーター顧客**
**2回以上** 注文している顧客について、「顧客ID」「注文回数」「初回注文日」「最終注文日」「初回から最終までの経過日数」を、注文回数の多い順に表示してください。

**(2) 休眠顧客**
**最終注文日が 2024年1月1日より前** の顧客を、最終注文日が古い順に表示してください。表示項目は「顧客ID」「注文回数」「最終注文日」です。

**(3)** (2) の結果に `customer_id = 6`（高橋 明）と `customer_id = 9`（伊藤 さやか）は現れません。それぞれ理由が異なります。なぜか説明してください。

### 解答:
```sql
-- (1) リピーター顧客
SELECT
    customer_id,
    COUNT(*) AS order_count,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    MAX(order_date) - MIN(order_date) AS active_days
FROM
    orders_trn
WHERE
    deleted_at IS NULL
GROUP BY
    customer_id
HAVING
    COUNT(*) >= 2
ORDER BY
    order_count DESC;

-- (2) 休眠顧客
SELECT
    customer_id,
    COUNT(*) AS order_count,
    MAX(order_date) AS last_order_date
FROM
    orders_trn
WHERE
    deleted_at IS NULL
GROUP BY
    customer_id
HAVING
    MAX(order_date) < '2024-01-01'
ORDER BY
    last_order_date;

-- (3)
-- customer_id=6（高橋 明）: 注文は1件あるが、それがキャンセル済み（order_id=9）。
--   WHERE deleted_at IS NULL で行が全部消えるため、グループそのものが作られない。
--   （customer_id=7 中村友子も order_id=18 がキャンセルだが、order_id=10 が生きているので現れる）
-- customer_id=9（伊藤 さやか）: orders_trn に1件も注文がない。
--   元から行が存在しないため、当然グループも作られない。
-- いずれも「orders_trn だけを見ている限り検出できない」。
-- 顧客マスタ側を基準にした集計は、外部結合（08章）やサブクエリ（10章）が必要になる。
```

### 期待結果:

(1) リピーター顧客

| customer_id | order_count | first_order_date | last_order_date | active_days |
| ---: | ---: | :--- | :--- | ---: |
| 1 | 6 | 2023-08-01 | 2024-08-21 | 386 |
| 2 | 4 | 2023-08-05 | 2024-08-07 | 368 |
| 3 | 2 | 2023-08-12 | 2023-09-15 | 34 |

(2) 休眠顧客

| customer_id | order_count | last_order_date |
| ---: | ---: | :--- |
| 4 | 1 | 2023-08-15 |
| 5 | 1 | 2023-08-22 |
| 7 | 1 | 2023-09-05 |
| 8 | 1 | 2023-09-10 |
| 3 | 2 | 2023-09-15 |

### 解説:
`MIN`/`MAX(order_date)` で初回・最終注文日が求まり、`日付 - 日付` は日数（整数）になります。(2) の `HAVING MAX(order_date) < '2024-01-01'`（集計結果での絞り込み）と `WHERE order_date < '2024-01-01'`（1回でも古い注文をした顧客まで拾ってしまう）は意味が違うので比較させると効果的です。(3) のように「1件も注文がない／全注文がキャンセル」の顧客は `orders_trn` 側からは `GROUP BY` で絶対に出てこず、検出には顧客マスタを基準にした結合（08章）が必要になります。

---

## 問題 15: 発注アラートレポート
- **目的**: `HAVING` 句で「グループ内の構成比」や「集合としての性質」を判定する（講義資料 §4-1・§5）。集計関数を `CASE` 式の条件に使う書き方を習得する。

### 問題:
`products_mst` テーブルの **販売中の商品** を対象に、以下の3つを算出してください。

**(1) 品揃えが潤沢なカテゴリ**
在庫数が 100 個以上の商品が、**そのカテゴリの商品数の半分以上** を占めるカテゴリを抽出してください。
表示項目は「カテゴリ名」「商品数」「在庫100個以上の商品数」です。

**(2) 全商品が欠品しているカテゴリ**
**そのカテゴリの商品すべてが在庫数0** になっているカテゴリを抽出してください。
表示項目は「カテゴリ名」「商品数」です。

**(3) 発注アラート付きの一覧**
カテゴリごとに「在庫数の合計」「在庫数0の商品数」を算出し、さらに **在庫数0の商品が1つ以上あるカテゴリには `要発注`、なければ `-`** を表示する列（`alert`）を追加してください。

### 解答:
```sql
-- (1) 在庫100個以上の商品が半数以上を占めるカテゴリ
SELECT
    category,
    COUNT(*) AS product_count,
    COUNT(CASE WHEN stock_quantity >= 100 THEN 1 END) AS abundant_count
FROM
    products_mst
WHERE
    deleted_at IS NULL
GROUP BY
    category
HAVING
    COUNT(CASE WHEN stock_quantity >= 100 THEN 1 END) >= COUNT(*) * 0.5
ORDER BY
    category;

-- (2) 全商品が在庫0のカテゴリ（全称命題）
SELECT
    category,
    COUNT(*) AS product_count
FROM
    products_mst
WHERE
    deleted_at IS NULL
GROUP BY
    category
HAVING
    COUNT(*) = COUNT(CASE WHEN stock_quantity = 0 THEN 1 END);

-- (3) 発注アラート付きの一覧
SELECT
    category,
    SUM(stock_quantity) AS total_stock,
    COUNT(CASE WHEN stock_quantity = 0 THEN 1 END) AS out_of_stock_count,
    CASE
        WHEN COUNT(CASE WHEN stock_quantity = 0 THEN 1 END) > 0 THEN '要発注'
        ELSE '-'
    END AS alert
FROM
    products_mst
WHERE
    deleted_at IS NULL
GROUP BY
    category
ORDER BY
    out_of_stock_count DESC, category;
```

### 期待結果:

(1) 品揃えが潤沢なカテゴリ

| category | product_count | abundant_count |
| :--- | ---: | ---: |
| Books | 5 | 3 |
| Electronics | 4 | 4 |
| Food | 4 | 3 |
| Stationery | 3 | 3 |

※ `Home & Kitchen`（3件中1件）と `Toys`（3件中0件）が除外されます。

(2) 全商品が在庫0のカテゴリ

| category | product_count |
| :--- | ---: |
| Toys | 3 |

(3) 発注アラート付きの一覧

| category | total_stock | out_of_stock_count | alert |
| :--- | ---: | ---: | :--- |
| Toys | 0 | 3 | 要発注 |
| Home & Kitchen | 190 | 1 | 要発注 |
| Books | 720 | 0 | - |
| Electronics | 970 | 0 | - |
| Food | 910 | 0 | - |
| Stationery | 1220 | 0 | - |

### 解説:
`COUNT(CASE WHEN 条件 THEN 1 END)` は、ELSEを書かないことで条件に合わない行がNULLになり `COUNT` が数えないことを利用した条件付きカウントです。(1) の構成比判定は `COUNT(条件) >= COUNT(*) * 0.5` のように割り算を避ける形にするのが定石（`/` で書くと問題11と同じ整数除算が起きる）。(2) の全称命題は「全体件数 = 条件に合う件数」で判定します。(3) のように `SELECT` 句のCASE式の中でも集計関数を使えますが、`WHERE` 句には書けません（評価順序の違いによる）。

---

## 問題 16: 条件付き平均と `ELSE 0` の罠
- **目的**: 「特定の条件に合う行だけの平均」を正しく求める書き方を身につけ、`ELSE 0` と書いた場合に何が起きるかを数値で確認する（講義資料 §4-4）。

### 問題:
`products_mst` テーブルの **販売中の商品** について、**カテゴリごと** に以下の3つの平均価格を並べて表示してください（いずれも小数第2位まで）。

1. **avg_all**: そのカテゴリの全商品の平均価格
2. **avg_in_stock**: **在庫がある商品（在庫数 > 0）だけ** の平均価格
3. **avg_wrong**: 条件に合わない行を `ELSE 0` として計算した平均価格（**わざと間違った書き方**）

そのうえで、`Home & Kitchen` と `Toys` の3つの値を比較し、**なぜ `avg_wrong` が使えないのか**、また **`Toys` の `avg_in_stock` がなぜ空欄（NULL）になるのか** を説明してください。

### 解答:
```sql
SELECT
    category,
    ROUND(AVG(price), 2) AS avg_all,
    ROUND(AVG(CASE WHEN stock_quantity > 0 THEN price END), 2) AS avg_in_stock,
    ROUND(AVG(CASE WHEN stock_quantity > 0 THEN price ELSE 0 END), 2) AS avg_wrong
FROM
    products_mst
WHERE
    deleted_at IS NULL
GROUP BY
    category
ORDER BY
    category;
```

### 期待結果:
| category | avg_all | avg_in_stock | avg_wrong |
| :--- | ---: | ---: | ---: |
| Books | 2760.00 | 2760.00 | 2760.00 |
| Electronics | 12020.00 | 12020.00 | 12020.00 |
| Food | 1600.00 | 1600.00 | 1600.00 |
| Home & Kitchen | 6600.00 | **5000.00** | **3333.33** |
| Stationery | 1510.00 | 1510.00 | 1510.00 |
| Toys | 4833.33 | **(NULL)** | **0.00** |

### 解説:
`ELSE 0` を書くと除外したい行が「0円」として分母に残ってしまい平均が歪みます（`Home & Kitchen` で3値が変わるのはこのため。在庫0の商品が無いカテゴリでは3列とも同じ値になります）。対象行が1件もない `Toys` の `avg_in_stock` はNULL（平均が定義できない、という正しい結果）になり、`avg_wrong` は誤って0.00になります。なお `SUM` は0を足しても合計が変わらないため、`ELSE 0` が危険なのは割り算（平均）のときだけです。

---

## 問題 17: 月次集計 ―― 年をまたいだ瞬間に壊れる集計
- **目的**: 「動いていたクエリが、データが増えた瞬間に間違った数字を返す」という実務で頻発する事故を体験し、月次集計の正しい書き方を習得する。

### 問題:

**(1)** `orders_trn` に対して **問題9と同じ考え方** で「月ごとの注文件数」を集計してください（`EXTRACT(MONTH FROM order_date)` でグループ化）。ただしキャンセルされた注文は除外します。

**(2)** (1) の結果の「8月」の件数を確認してください。実際の注文データと照らし合わせると、この数字は何を合算してしまっているでしょうか。

**(3)** 「**2023年8月**」「**2024年8月**」を別の行として集計できるように修正してください。
表示項目は「年月（`YYYY-MM` 形式）」と「注文件数」で、年月の昇順に並べてください。

### 解答:
```sql
-- (1) 問題9と同じ考え方（EXTRACT(MONTH) だけでグループ化）
SELECT
    EXTRACT(MONTH FROM order_date) AS order_month,
    COUNT(*) AS order_count
FROM
    orders_trn
WHERE
    deleted_at IS NULL
GROUP BY
    order_month
ORDER BY
    order_month;

-- (2)
-- 「8月」が10件になっている。
-- これは 2023年8月の8件 と 2024年8月の2件 を合算した数字。
-- EXTRACT(MONTH) は月の数字しか取り出さないため、年の情報が失われ、
-- 異なる年の同じ月が同じグループにまとめられてしまう。

-- (3) 年月でグループ化する
SELECT
    TO_CHAR(order_date, 'YYYY-MM') AS year_month,
    COUNT(*) AS order_count
FROM
    orders_trn
WHERE
    deleted_at IS NULL
GROUP BY
    year_month
ORDER BY
    year_month;
```

### 期待結果:

(1) 壊れている集計

| order_month | order_count |
| ---: | ---: |
| 2 | 2 |
| 3 | 1 |
| 8 | **10** ← 2023年8月と2024年8月が合算されている |
| 9 | 3 |

(3) 正しい月次集計

| year_month | order_count |
| :--- | ---: |
| 2023-08 | 8 |
| 2023-09 | 3 |
| 2024-02 | 2 |
| 2024-03 | 1 |
| 2024-08 | 2 |

### 解説:
`EXTRACT(MONTH)` だけでは年の情報が失われ、異なる年の同じ月が合算されます（問題9と同じ書き方が、2024年のデータが増えた瞬間に壊れる例）。年をまたぐ月次集計は `TO_CHAR(order_date, 'YYYY-MM')` のように年月単位でグループ化します。ただし「季節性を見たい」場合は `EXTRACT(MONTH)` の方が正解なので、目的次第で使い分けます。

---

## 問題 18: 商品別の売れ筋ランキング（指標の選び方）
- **目的**: 同じテーブルでも集計の「軸」を変えると別の指標になることを理解する。あわせて「売れ筋」をどの指標で測るべきかを考える。

### 問題:
`order_details_trn` テーブル（キャンセル分は除外）から、**商品ごと** に以下を算出してください。

1. **order_count**: その商品が含まれていた注文の件数
2. **total_quantity**: 販売された合計個数

**(1)** `total_quantity` の多い順に並べて表示してください。
**(2)** `order_count` の多い順に並べて表示してください。
**(3)** (1) と (2) で1位の商品が入れ替わります。それぞれの1位の商品IDを挙げ、**「売れ筋商品」をレポートするならどちらの指標を使うべきか**、理由とともに述べてください。

### 解答:
```sql
-- (1) 販売個数の多い順
SELECT
    product_id,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(quantity) AS total_quantity
FROM
    order_details_trn
WHERE
    deleted_at IS NULL
GROUP BY
    product_id
ORDER BY
    total_quantity DESC;

-- (2) 注文件数の多い順
SELECT
    product_id,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(quantity) AS total_quantity
FROM
    order_details_trn
WHERE
    deleted_at IS NULL
GROUP BY
    product_id
ORDER BY
    order_count DESC;

-- (3)
-- (1) の1位: product_id=15（国産はちみつ）… 合計502個だが、注文はたった2件
-- (2) の1位: product_id=1（ワイヤレスイヤホン）… 4件の注文で、合計4個
--
-- 「売れ筋」としてレポートするなら order_count（注文件数）を主に見るべき。
-- product_id=15 の502個は、order_id=10 の500個という1件の大口注文で作られた数字であり、
-- 「多くの顧客に繰り返し買われている」という意味での売れ筋ではない。
-- 合計個数は1件の外れ値で順位が簡単に入れ替わるため、
-- 実務では「注文件数」「購入した顧客数」「合計個数」を並べて見るのが基本。
```

### 期待結果:

(1) 販売個数の多い順（上位）

| product_id | order_count | total_quantity |
| ---: | ---: | ---: |
| 15 | 2 | **502** |
| 6 | 2 | 6 |
| 8 | 2 | 5 |
| 1 | 4 | 4 |
| 16 | 1 | 3 |
| 2 | 3 | 3 |
| 10 | 1 | 2 |
| 21 | 1 | 2 |

(2) 注文件数の多い順（上位）

| product_id | order_count | total_quantity |
| ---: | ---: | ---: |
| 1 | **4** | 4 |
| 2 | 3 | 3 |
| 6 | 2 | 6 |
| 8 | 2 | 5 |
| 15 | 2 | 502 |
| 3 | 1 | 1 |
| 4 | 1 | 1 |
| 5 | 1 | 1 |

### 解説:
同じテーブル・同じ集計関数でも `GROUP BY` の軸を変えると別の指標になります（問題7は `order_id` 軸、これは `product_id` 軸）。`product_id=15`（国産はちみつ）は在庫を超える大口注文（500個）が仕込まれており、これ1件で `total_quantity` の順位が歪みます。「売れ筋」を測るなら、外れ値に弱い合計個数より `order_count`（何件の注文で買われたか）を主指標にする方が実務的です。売上金額や商品名を出すには `products_mst` との結合（08章）が必要になります。
