# 03章 演習 解答：DELETE文

**PostgreSQL 17 で実際に動かした結果を載せています。** この章では学習目的で `DELETE` 文による**物理削除**（レコードを完全に消す操作）を行います。テーブルには**外部キー制約**が設定されているため、親テーブル（顧客や商品）をいきなり削除しようとしてもエラーになります。**「子テーブル（参照している側）から先に削除する」**というデータベースの整合性を保つためのルールを意識して解答してください。

**1問解くごとにデータが消えます。** 次の問題に進む前に、下の「準備」にある**リセット手順**で初期状態に戻してください。

---

## 準備

### 使用するテーブル

02章で作成した `customers_mst` / `products_mst` / `orders_trn` / `order_details_trn` をそのまま使います。まだ作っていない場合は、02章の DDL スクリプト（`02_DDL（前半用）`）を実行して作成してください。

初期状態の件数は **顧客 9 件 / 商品 23 件 / 注文 18 件 / 注文明細 28 件** です。

### テーブルの親子関係

外部キーは次の3本です。削除は矢印の**逆向き**（参照している側から）に進めます。

- `orders_trn.customer_id` → `customers_mst.customer_id`
- `order_details_trn.order_id` → `orders_trn.order_id`
- `order_details_trn.product_id` → `products_mst.product_id`

### リセット手順

**1問解くごとに、次の手順でデータベースを作り直してください。**

1. `DROP DATABASE` → `CREATE DATABASE`（pgAdmin なら削除 → 新規作成）
2. DDL を実行する
3. テストデータの `INSERT` を実行する

初期状態に戻ったかどうかは、次のSQLで確認できます。**9 / 23 / 18 / 28** になっていればOKです。

```sql
SELECT (SELECT COUNT(*) FROM customers_mst)     AS customers,
       (SELECT COUNT(*) FROM products_mst)      AS products,
       (SELECT COUNT(*) FROM orders_trn)        AS orders,
       (SELECT COUNT(*) FROM order_details_trn) AS details;
```

---

## 問題 1: 特定の商品を削除する
- **目的**: 外部キー制約がある場合の基本的な削除手順（子 → 親）を理解する。

### 問題:
`products_mst` テーブルから、商品名が **「セラミックフライパン」** の情報を削除してください。

### 解答:
```sql
-- まず、この商品が含まれている注文明細を削除し、その後に商品を削除する

-- 1. 注文明細(子)を削除（サブクエリを使用する例）
DELETE FROM order_details_trn
WHERE product_id = (SELECT product_id FROM products_mst WHERE product_name = 'セラミックフライパン');

-- 2. 商品(親)を削除
DELETE FROM products_mst
WHERE product_name = 'セラミックフライパン';
```

### 解説:
子テーブルから参照されたままの親行は外部キー制約に阻まれて削除できないため、先に注文明細を消す必要があります。いきなり親を消そうとすると次のエラーになります。

```sql
-- ❌ よくある間違い
DELETE FROM products_mst WHERE product_name = 'セラミックフライパン';
```

```
ERROR:  update or delete on table "products_mst" violates foreign key constraint "order_details_trn_product_id_fkey" on table "order_details_trn"
DETAIL:  Key (product_id)=(12) is still referenced from table "order_details_trn".
```

実務では物理削除を行わず、`deleted_at` に日時を入れる「論理削除」を行うのが一般的です（→ 問題 8）。

---

## 問題 2: 在庫がゼロの商品を全て削除する
- **目的**: 条件に合致する複数の行を、整合性を保ちながら一括削除する方法を理解する。

### 問題:
`products_mst` テーブルから、在庫数(`stock_quantity`)が **0 個** の商品を全て削除してください。

### 解答:
```sql
-- 在庫0の商品IDを特定し、明細 → 商品の順で削除する

-- 1. 在庫0の商品が含まれる注文明細を削除
DELETE FROM order_details_trn
WHERE product_id IN (SELECT product_id FROM products_mst WHERE stock_quantity = 0);

-- 2. 在庫0の商品自体を削除
DELETE FROM products_mst
WHERE stock_quantity = 0;
```

### 解説:
削除対象が複数行になるので、問題1の `=` ではなく `IN` を使います（`=` のままだとサブクエリが複数行を返してエラーになります）。手順1で先に明細を消しても、手順2の条件は `products_mst` を見ているのでズレません（実測で明細2件・商品4件が削除されます）。

---

## 問題 3: 特定のカテゴリに属する商品をまとめて削除する
- **目的**: `WHERE` 句でカテゴリを指定し、関連する複数の子レコードと親レコードを処理する。

### 問題:
`products_mst` テーブルから、カテゴリ(`category`)が **'Food'** の全ての商品を削除してください。

### 解答:
```sql
-- 1. 'Food'カテゴリ商品の注文明細を削除
DELETE FROM order_details_trn
WHERE product_id IN (SELECT product_id FROM products_mst WHERE category = 'Food');

-- 2. 'Food'カテゴリの商品を削除
DELETE FROM products_mst
WHERE category = 'Food';
```

---

## 問題 4: 長期間利用がない顧客を削除する
- **目的**: 3階層のテーブル（明細 → 注文 → 顧客）の削除順序と、日付比較を理解する。

### 問題:
`customers_mst` テーブルから、**2023年3月1日より前** に登録された顧客の情報を削除してください。

> **ヒント**: 顧客(`customers_mst`)を消すには、その顧客の注文(`orders_trn`)を消す必要があり、注文を消すには注文明細(`order_details_trn`)を消す必要があります。

### 解答:
```sql
-- 最も深い階層（孫テーブル）から順に削除する。
-- 対象: 2023-03-01 より前の顧客 (customer_id: 1, 2 が該当)

-- 1. [孫] 対象顧客の注文に紐づく「注文明細」を削除
DELETE FROM order_details_trn
WHERE order_id IN (
    SELECT order_id
    FROM orders_trn
    WHERE customer_id IN (SELECT customer_id FROM customers_mst WHERE created_date < '2023-03-01')
);

-- 2. [子] 対象顧客の「注文」を削除
DELETE FROM orders_trn
WHERE customer_id IN (SELECT customer_id FROM customers_mst WHERE created_date < '2023-03-01');

-- 3. [親] 「顧客」自体を削除
DELETE FROM customers_mst
WHERE created_date < '2023-03-01';
```

### 解説:
3つの `DELETE` はどれも `customers_mst` を基準に対象を絞っています。そのため**顧客を先に消すと残り2つの条件が空振りし、子データが親のない状態で残ります**（外部キー制約があるので実際にはエラーで止まります）。順序が意味を持つのはこのためです。`created_date < '2023-03-01'` は「より前」なので `<`。`<=` にすると 2023-03-01 登録の田中 健太まで巻き込みます。

---

## 問題 5: メモが設定されていない商品を削除する
- **目的**: `IS NULL` を用いた削除条件と、リレーションの解消。

### 問題:
`products_mst` テーブルから、メモ(`memo`)が **NULL** である商品を全て削除してください。

### 解答:
```sql
-- 1. メモがNULLの商品の注文明細を削除
DELETE FROM order_details_trn
WHERE product_id IN (SELECT product_id FROM products_mst WHERE memo IS NULL);

-- 2. メモがNULLの商品を削除
DELETE FROM products_mst
WHERE memo IS NULL;
```

### 解説:
NULL は `=` で比較できないため、`memo = NULL` ではなく `memo IS NULL` と書きます。`memo = NULL` はエラーにならず常に0件になるので、「消えなかった」ことに気づきにくい間違いです。

---

## 問題 6: 特定の顧客IDに関連するデータを削除する
- **目的**: 特定のIDを指定して、関連データを手動でクリーンアップする手順を確実に遂行する能力を養う。

### 問題:
**customer_id が 4** の顧客（山田 恵美）について、以下の手順でデータを削除してください。
1. この顧客が購入した全ての「注文明細」
2. この顧客の「注文履歴」
3. この顧客の「顧客情報」

### 解答:
```sql
-- IDを指定して、深い階層から確実に消していく手順

-- 1. まず、削除対象の顧客に関連する注文の order_id を確認（実務的な手順）
SELECT order_id FROM orders_trn WHERE customer_id = 4;
-- 結果: order_id = 5 の1件

-- 2. 注文明細(order_details_trn)を削除
DELETE FROM order_details_trn
WHERE order_id IN (SELECT order_id FROM orders_trn WHERE customer_id = 4);
-- または確認したIDを使って: DELETE FROM order_details_trn WHERE order_id = 5;

-- 3. 注文(orders_trn)を削除
DELETE FROM orders_trn
WHERE customer_id = 4;

-- 4. 顧客(customers_mst)を削除
DELETE FROM customers_mst
WHERE customer_id = 4;
```

### 解説:
消す前に `SELECT` で対象を確認するのは実務の基本動作です（`DELETE` は元に戻せないため）。`ON DELETE CASCADE` が設定されているテーブルであれば親を消すだけで子も自動で消えますが、どこまで消えるかが見えない危険な操作になりうるため、意図して手動削除を行うケースも多々あります。

---

## 問題 7: 【極めて危険！】 全ての注文データを削除する
- **目的**: `WHERE` 句なしの `DELETE` の危険性と、全件削除時における外部キー制約の影響を理解する。

### 問題:
`orders_trn` テーブルの **全ての注文情報** を削除してください。
※実務環境では絶対に行わないでください。

### 解答:
```sql
-- 全件削除であっても、参照されている子テーブルから消す必要がある

-- 1. 注文明細を全て削除
DELETE FROM order_details_trn;

-- 2. 注文を全て削除
DELETE FROM orders_trn;
```

### 解説:
`WHERE` 句の有無にかかわらず外部キー制約は効くため、子テーブルに1行でも残っていれば親の全件削除は失敗します。

```sql
-- ❌ 実行できない例
DELETE FROM orders_trn;
```

```
ERROR:  update or delete on table "orders_trn" violates foreign key constraint "order_details_trn_order_id_fkey" on table "order_details_trn"
DETAIL:  Key (order_id)=(1) is still referenced from table "order_details_trn".
```

ただしこの失敗は制約が偶然止めてくれただけで、正しい順序（子 → 親）で書けば `DELETE 28` / `DELETE 18` と全件が消えます。`WHERE` の付け忘れを止めてくれる仕組みは無い、というのが本題です。

> **⚠️ 講師向けの注意**: `DELETE` は物理的にデータを消してしまうため、復元が困難です。実務では `deleted_at` カラムに日付を入れる `UPDATE` 文（論理削除）を使うことがほとんどであることを併せて指導すること！

---

## 追加課題（ここから先は任意）

**問題 7 まで**が必須です。ここから先は、早く終わった人・もっと解きたい人向けです。

> **注意**: ここから先の問題も物理削除を行います。各問を解き終えたら「準備」のリセット手順を必ず実行してください（04章・06章・07章の期待結果はこのデータが揃っている前提です）。

---

## 問題 8: 消す前に「参照されているか」を確かめる
- **目的**: `DELETE ... RETURNING` で削除した行の内容を証跡として取得しつつ、「参照されていない行は消せる／参照されている行は消せない」の違いから、なぜ実務が論理削除を選ぶのかを説明できるようにする。

### 問題:
商品マスタの棚卸しで、重複登録が2件見つかりました。

- `product_id = 20`: 商品名が `' 国産はちみつ '` と前後に空白付きで登録されており、`product_id = 15` と実質同じ商品
- `product_id = 19`: 商品名が `'SQL 入門'` で、`product_id = 2` と同名の二重登録

**(1)** `product_id = 20` を物理削除してください。その際、**削除した行の内容を `RETURNING` で出力** してください。

**(2)** 同じやり方で `product_id = 19` を削除してください。何が起きますか。エラーメッセージを読み、原因を説明してください。

**(3)** (2) を成功させる手順を書いてください。ただし、**その手順を実行すると業務上どんな情報が失われるか** も答えてください。

**(4)** この2件は、それぞれ物理削除・論理削除のどちらで処理すべきでしょうか。理由とともに述べてください。

> **ヒント**: エラーメッセージの `DETAIL:` 行には、どのテーブルのどのキーが参照しているかが必ず書かれています。

> **この問題を解き終えたら、「準備」のリセット手順でデータベースを作り直してください。**

### 解答:
```sql
-- (1) 削除した行の内容を RETURNING で証跡として受け取る
DELETE FROM products_mst
WHERE product_id = 20
RETURNING *;

-- (2) 同じやり方で product_id = 19 を削除しようとすると、次のエラーになる
DELETE FROM products_mst
WHERE product_id = 19
RETURNING *;
-- ERROR:  update or delete on table "products_mst" violates foreign key constraint
--         "order_details_trn_product_id_fkey" on table "order_details_trn"
-- DETAIL:  Key (product_id)=(19) is still referenced from table "order_details_trn".
--
-- product_id=19 は order_details_trn から1行参照されている（order_id=16 / 鈴木 花子 / 2024-08-07）。
-- 外部キー制約が「まだ使われているデータを消させない」ため、親の削除がブロックされている。
-- 一方 product_id=20 はどこからも参照されていないので、そのまま消せた。

-- (3) 成功させるには、参照している子（注文明細）を先に消してから親を消す
DELETE FROM order_details_trn
WHERE product_id = 19
RETURNING *;

DELETE FROM products_mst
WHERE product_id = 19
RETURNING *;
--
-- 失われる情報: 「鈴木 花子が 2024-08-07 に SQL 入門を1個購入した」という売上明細そのもの。
-- マスタの重複を掃除するために、無関係な売上実績を1件消してしまっている。

-- (4)
-- product_id=20（' 国産はちみつ '）: 一度も注文されていない純粋な誤登録 → 物理削除でよい。
-- product_id=19（'SQL 入門'）: 売上実績がある → 物理削除すると売上履歴が壊れるので、
--   次のように論理削除して商品一覧から隠すのが正解。
--   UPDATE products_mst SET deleted_at = NOW() WHERE product_id = 19;
```

### 期待結果:

(1) `RETURNING *` の出力 ―― 削除された1行がそのまま返る

| product_id | category | product_name | price | stock_quantity | memo | deleted_at |
| ---: | :--- | :--- | ---: | ---: | :--- | :--- |
| 20 | Food | ` 国産はちみつ ` | 1200.00 | 30 | (NULL) | (NULL) |

(2) の実行結果 ―― 1行も削除されずエラーで停止します。`DETAIL:` 行に `Key (product_id)=(19) is still referenced from table "order_details_trn".` と、参照元のテーブルとキーが明示されます。

(3) の実行結果 ―― `order_details_trn` から `(16, 19, 1)` が、`products_mst` から `product_id = 19` の行が、それぞれ1行ずつ `RETURNING` で返って削除されます。

### 解説:
同じ「重複データの掃除」でも、参照されているかどうかで手順も是非も変わり、外部キー制約はまだ使われているデータを消させない安全装置として働きます（どのテーブルのどのキーが参照しているかはエラーの `DETAIL:` 行に必ず書かれている）。`RETURNING` は削除した行をその場で返すので、元に戻せない `DELETE` にとって唯一の証跡となり、実務では実行ログとして必ず残します。

> **注意**: (2) はエラーになるため、トランザクション内で試している場合はいったん `ROLLBACK;` してから (1) をやり直し、(3) に進んでください。

---

## 問題 9: 論理削除済みデータの一掃（パージ）
- **目的**: `deleted_at IS NOT NULL` を削除条件にして「論理削除済みの行を物理的に消す定期バッチ」を、親子関係の順序を守って書けるようにする。

### 問題:
「キャンセル済みの注文を、DBから完全に削除してほしい」という依頼を受けました。

**(1)** まず削除対象を確認します。`orders_trn` と `order_details_trn` に、論理削除済み（`deleted_at` が入っている）の行はそれぞれ何件ありますか。

**(2)** いきなり `DELETE FROM orders_trn WHERE deleted_at IS NOT NULL;` を実行するとどうなりますか。

**(3)** 正しい順序でパージ（物理削除）を実行してください。

**(4)** パージ後、`customer_id = 6`（高橋 明）の注文は何件になりますか。またこの顧客は、注文履歴のうえで `customer_id = 9`（伊藤 さやか）とどう区別がつかなくなりますか。それはなぜ問題なのでしょうか。

> **この問題を解き終えたら、「準備」のリセット手順でデータベースを作り直してください。**

### 解答:
```sql
-- (1) 削除対象の件数を先に確認する（消す前の確認は必須）
SELECT COUNT(*) AS cancelled_orders
FROM orders_trn
WHERE deleted_at IS NOT NULL;

SELECT COUNT(*) AS cancelled_details
FROM order_details_trn
WHERE deleted_at IS NOT NULL;

-- (2) 親（注文）から消そうとすると外部キー制約違反でエラーになる
DELETE FROM orders_trn
WHERE deleted_at IS NOT NULL;
-- ERROR:  update or delete on table "orders_trn" violates foreign key constraint
--         "order_details_trn_order_id_fkey" on table "order_details_trn"
-- DETAIL:  Key (order_id)=(9) is still referenced from table "order_details_trn".

-- (3) 子（注文明細）→ 親（注文）の順にパージする
DELETE FROM order_details_trn
WHERE deleted_at IS NOT NULL;

DELETE FROM orders_trn
WHERE deleted_at IS NOT NULL;

-- (4) パージ後の高橋 明（customer_id = 6）の注文件数
SELECT COUNT(*) AS akira_orders
FROM orders_trn
WHERE customer_id = 6;
--
-- 0件になる。高橋 明の注文は order_id=9 の1件だけで、それがキャンセル済みだったため消えた。
-- 一度も注文したことがない伊藤 さやか（customer_id=9）も0件なので、注文履歴のうえでは
-- 両者がまったく同じ「注文0件の顧客」に見えてしまう。
-- 「注文したがキャンセルした顧客」と「そもそも注文したことがない顧客」は、
-- 販促やサポートの打ち手がまるで違うのに、その区別が永久に失われる。
```

### 期待結果:

(1) 削除対象の件数

| クエリ | 結果 |
| :--- | ---: |
| cancelled_orders | 2 |
| cancelled_details | 2 |

該当行は `orders_trn` が `order_id` = 9, 18、`order_details_trn` が `(9, 13)` と `(18, 17)` です。

(3) パージの実行結果 ―― `DELETE 2` が2回。`orders_trn` は 18 → 16 件、`order_details_trn` は 28 → 26 件になります。

(4) `akira_orders` は **0**。伊藤 さやか（`customer_id = 9`）も 0 件のため、両者が区別できなくなります。

### 解説:
論理削除済みの行を後から物理削除する処理はパージと呼ばれ、実運用でも定期的に行います（削除条件が `WHERE deleted_at IS NOT NULL` という論理削除フラグそのものになる点だけが特徴で、子 → 親という順序は通常の削除と同じ）。ただし (4) が示すとおり、パージには「キャンセルという事実そのもの」を失う不可逆な副作用があります。パージ要件が来たら、本当に消してよいか・退避先はあるかを必ず確認してください。

> **注意**: (2) はエラーになるため、トランザクション内で試している場合はいったん `ROLLBACK;` してから (3) に進んでください。

> **⚠️ 講師向けの注意**: リセットを忘れると 04章・06章・07章の期待結果が合わなくなるため、演習の終わりに `orders_trn` 18件 / `order_details_trn` 28件 / `products_mst` 23件 を全員に確認させること。
