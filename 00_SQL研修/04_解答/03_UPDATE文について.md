# 03章 演習 解答：UPDATE文

**PostgreSQL 17 で実際に動かした結果を載せています。** 使用するテーブルは02章で作成した `products_mst` / `customers_mst` / `orders_trn` / `order_details_trn` です。

この章の問題は**データを書き換えます。** 値が分からなくなったら、下の「準備」にあるリセット手順で初期状態に戻してください。

---

## 準備

### 使用するテーブル

**02章で作成した `products_mst` / `customers_mst` / `orders_trn` / `order_details_trn` をそのまま使います。** 新しく作るものはありません。
まだ作っていない場合は、02章の DDL スクリプト（`02_DDL（前半用）`）を実行して作成してください。

### リセット手順

この章の問題は**データを書き換えます。** 値が分からなくなったら、**DBを作り直して入れ直します。**

1. `DROP DATABASE` → `CREATE DATABASE`
2. DDL を実行する
3. テストデータの `INSERT` を実行する

**問題10（全件の価格を0にする）を実行したあとと、追加課題に入る前には必ずやり直してください。**

---

## 問題 1: 特定商品の価格を変更する
- **目的**: `UPDATE` 文と `WHERE` 句を用いて、特定の 1 つの行の特定の列の値を更新する基本を理解する。

### 問題:
`products_mst` テーブルの **「ワイヤレスイヤホン」** の価格を、現在の 12,800.00 円から **11,980.00 円** に更新してください。

### 解答:
```sql
UPDATE products_mst
SET price = 11980.00
WHERE product_name = 'ワイヤレスイヤホン';
```

---

## 問題 2: 複数の情報を同時に更新する
- **目的**: 1 つの `UPDATE` 文で複数の列(`column1 = val1, column2 = val2`)を同時に更新する方法を理解する。

### 問題:
`products_mst` テーブルの **`product_id` が 2 の「SQL 入門」** について、以下の 2 つの情報を同時に更新してください。

1. 価格を **2,200.00 円** に変更する。
2. 在庫数を **180 個** に変更する。

### 解答:
```sql
UPDATE products_mst
SET price = 2200.00,
    stock_quantity = 180
WHERE product_id = 2;
```

### 解説:
`WHERE product_name = 'SQL 入門'` と書くと、同名で二重登録されている `product_id = 19` の行まで更新され `UPDATE 2` になります。`UPDATE` の `WHERE` には原則として主キーを使ってください（詳しくは問題13）。

---

## 問題 3: 在庫数に基づいて商品の価格を割引する
- **目的**: 既存の列の値を参照して計算し、その結果で自分自身の列を更新する（相対的な更新）方法を理解する。

### 問題:
`products_mst` テーブルで、在庫数(`stock_quantity`)が **200 個以上** ある商品の価格を、現在の価格から **10% 割引** （0.9倍）してください。

### 解答:
```sql
UPDATE products_mst
SET price = price * 0.9
WHERE stock_quantity >= 200;
```

### 解説:
`price = price * 0.90` や `price = price - (price * 0.10)` など、計算式の書き方は複数ありますが、結果は同じです。なお現在値を元に計算する相対的な更新なので、間違えて2回実行すると 0.81 倍になります（同じSQLを何度実行しても同じ結果になるとは限りません）。

---

## 問題 4: 特定カテゴリの商品のメモを更新する
- **目的**: `WHERE` 句でカテゴリを指定し、複数の行を一括で更新する方法、および `TEXT` 型の更新を理解する。

### 問題:
`products_mst` テーブルで、カテゴリ(`category`)が **'Books'** の全ての商品について、メモ欄(`memo`)を **'人気書籍'** に書き換えてください。

### 解答:
```sql
UPDATE products_mst
SET memo = '人気書籍'
WHERE category = 'Books';
```

---

## 問題 5: 登録日が古い顧客のメールアドレスを更新する（文字列置換）
- **目的**: `WHERE` 句での日付比較と、関数（`REPLACE`）を用いた更新を理解する。

### 問題:
`customers_mst` テーブルで、**2023年4月1日より前** に登録された顧客のメールアドレスについて、ドメイン部分を `@example.com` から **`@newcompany.com`** に変更してください。
（例: `sato.taro@example.com` → `sato.taro@newcompany.com`）

> **ヒント**: 文字列の置換には `REPLACE()` 関数が使えます。

### 解答:
```sql
UPDATE customers_mst
SET email = REPLACE(email, '@example.com', '@newcompany.com')
WHERE created_date < '2023-04-01';
```

### 解説:
`REPLACE(対象列, '探す文字', '置換する文字')` は、PostgreSQL等のDBで使える文字列操作関数です。対象は `created_date` が 2023-01-15・2023-02-20・2023-03-01 の3名で、`UPDATE 3` が返ります。

---

## 問題 6: 特定の顧客の最近の注文日を更新する
- **目的**: 実務でよくある「特定条件のレコードを目視確認してからID指定で更新する」という手順を学ぶ（まだサブクエリを使わない方法）。

### 問題:
`orders_trn` テーブルで、customer_id が 1 の顧客（佐藤 太郎）の **最も新しい注文日** を **2024-08-30** に修正してください。
※いきなりUPDATEせず、まずは対象の注文IDを特定してから更新を行ってください。

### 解答:
```sql
-- 手順1. customer_id=1 の注文を日付の新しい順に表示し、一番上の order_id を確認する
SELECT order_id, order_date
FROM orders_trn
WHERE customer_id = 1
ORDER BY order_date DESC;

-- 結果: order_id=17 (2024-08-21) が一番上に来る
--   17 | 2024-08-21
--   15 | 2024-03-05
--   13 | 2024-02-14
--    8 | 2023-08-25
--    3 | 2023-08-10
--    1 | 2023-08-01

-- 手順2. 特定した order_id を使って更新する
UPDATE orders_trn
SET order_date = '2024-08-30'
WHERE order_id = 17;
```

### 解説:
条件が複雑な場合や「最新の1件だけ」といった更新を行いたい場合、初心者のうちは無理に1つのSQLにまとめず、このように「SELECTでID特定」→「ID指定でUPDATE」とするのが確実で安全です。

---

## 問題 7: メモが NULL の商品にデフォルト値を設定する
- **目的**: `IS NULL` 演算子を使って、NULL 値を持つ行のみを対象に更新を行う。

### 問題:
`products_mst` テーブルで、メモ(`memo`)がまだ登録されていない（NULL である）商品のメモ欄を、**'詳細未設定'** という文字列に更新してください。

### 解答:
```sql
UPDATE products_mst
SET memo = '詳細未設定'
WHERE memo IS NULL;
```

---

## 問題 8: 売れ残りの可能性のある商品の在庫をゼロにする
- **目的**: 複数の `WHERE` 条件を `AND` で組み合わせ、特定のビジネスロジックに基づいた一括更新を行う。

### 問題:
`products_mst` テーブルで、以下の条件を両方満たす商品の在庫数(`stock_quantity`)を **0** に変更してください。

1. 価格が **2,000 円未満**
2. 在庫数が **0 より大きい**（まだ在庫がある）

### 解答:
```sql
UPDATE products_mst
SET stock_quantity = 0
WHERE price < 2000
  AND stock_quantity > 0;
```

---

## 問題 9: 論理削除を行う
- **目的**: 物理削除（DELETE）ではなく、フラグや日時項目を更新することで削除扱いにする「論理削除」の実装方法を学ぶ。

### 問題:
`products_mst` テーブルで、**product_id が 1** の商品を論理削除してください。
※このテーブルでは `deleted_at` カラムに日時が入っているデータを「削除済み」とみなします。現在の日時(`NOW()`)をセットしてください。

### 解答:
```sql
UPDATE products_mst
SET deleted_at = NOW()
WHERE product_id = 1;
```

### 解説:
`NOW()` は現在の日時を取得するPostgreSQLの関数です。実務ではこのように `UPDATE` 文を使って削除日時を記録し、データそのものは消さない運用が一般的です。

---

## 問題 10: 【危険！】 全ての商品価格をゼロにする
- **目的**: `WHERE` 句を付けずに `UPDATE` 文を実行した場合の危険性（全件更新）を認識する。

### 問題:
`products_mst` テーブルの **全ての商品の価格** を **0.00 円** に更新してください。

**⚠️ 警告**: この操作はテーブルの全てのデータに影響を与えます。実務環境では絶対に行わないでください。

### 解答:
```sql
UPDATE products_mst
SET price = 0.00;
-- WHERE 句がないため、全ての行の price が 0 になります
```

### 解説:
`UPDATE 23` が返り、23件すべての価格が0円になります。**実行したら必ず「準備」のリセット手順でDBを作り直してください。**

> **⚠️ 講師向けの注意**: `UPDATE` や `DELETE` を実行する際は、必ず `WHERE` 句で対象が絞り込まれているか確認する癖をつけましょう。実務では、まず `SELECT` 文で `WHERE` 条件をテストしてから、その条件を `UPDATE` 文にコピー＆ペーストすると安全です。

---

## 追加課題（ここから先は任意）

**問題 10 まで**が必須です。ここから先は、早く終わった人・もっと解きたい人向けです。

> **注意**: 追加課題を始める前に、**必ず「準備」のリセット手順でDBを作り直してください**（問題10で全商品の価格が0になっているため、そのままでは以下の設問の更新件数が合いません）。
> 追加課題の各問もデータを変更しますが、`BEGIN;` … `ROLLBACK;` で囲む形にしてあるので、**そのとおりに実行すればリセットは要りません。**

---

## 問題 11: WHERE は「対象を選ぶ」だけでなく「対象外を守る」ために書く
- **目的**: `UPDATE` の `WHERE` に `deleted_at IS NULL` を加えて販売終了データを巻き込まないようにし、更新件数を毎回確認する習慣をつける（「0件更新」がエラーにならない危険も含む）。

### 問題:
`products_mst` テーブルに対して在庫補充を行います。
**SQLを実行するたびに、返ってくる `UPDATE 〇` の件数を必ず記録してください。**

**(1)** `Toys` カテゴリの **販売中の商品**（`deleted_at` が NULL の商品）の在庫数を、それぞれ **30 個ずつ増やして** ください。何件更新されましたか。

**(2)** 同じように `Electronics` カテゴリの **販売中の商品** の在庫数を、それぞれ **50 個ずつ増やして** ください。何件更新されましたか。
あわせて、`deleted_at IS NULL` を書かなかった場合は対象が何件になり、どの商品が巻き込まれるかを `SELECT` で確認してください（`UPDATE` は実行しないこと）。

**(3)** (2) のSQLのカテゴリ名を `'electronics'`（すべて小文字）に書き換えて実行してください。何件更新され、エラーは出ますか。

**この問のSQLは `BEGIN;` … `ROLLBACK;` で囲んで実行してください。** 確定させると、この章より後の集計結果が教材と合わなくなります。

> **ヒント**: 「30個増やす」は現在の在庫数を参照する相対的な更新です（問題3と同じ考え方）。

### 解答:
```sql
BEGIN;

-- (1) Toys の販売中商品の在庫を各30個増やす → UPDATE 3
UPDATE products_mst
SET stock_quantity = stock_quantity + 30
WHERE category = 'Toys'
  AND deleted_at IS NULL;

-- (2) Electronics の販売中商品の在庫を各50個増やす → UPDATE 4
UPDATE products_mst
SET stock_quantity = stock_quantity + 50
WHERE category = 'Electronics'
  AND deleted_at IS NULL;

-- (2) deleted_at IS NULL を書かなかったら何が対象になるかを SELECT で確認する（5件）
SELECT product_id, product_name, deleted_at
FROM products_mst
WHERE category = 'Electronics'
ORDER BY product_id;
-- → product_id=11「ゲーミングマウス」（2023-09-20 販売終了）が混入する

-- (3) カテゴリ名を小文字にして実行 → UPDATE 0（エラーは出ない）
UPDATE products_mst
SET stock_quantity = stock_quantity + 50
WHERE category = 'electronics'
  AND deleted_at IS NULL;

ROLLBACK;   -- 加算した在庫を確定させずに捨てる
```

### 期待結果:

更新件数

| 実行した `UPDATE` | 更新件数 | 対象の product_id |
| :--- | ---: | :--- |
| (1) Toys に +30 | 3 | 17, 18, 23 |
| (2) Electronics に +50 | 4 | 1, 4, 8, 14 |
| (2) `deleted_at IS NULL` を外した場合 | 5 | 1, 4, 8, 11, 14 |
| (3) `category = 'electronics'` | 0 | （なし・エラーも出ない） |

### 解説:
`WHERE` は更新する行を選ぶためだけでなく、**更新してはいけない行（販売終了商品）を守る** ためにも書きます。(3) のようにカテゴリ名が1文字違ってもエラーにはならず `UPDATE 0` が返るだけなので、更新件数が想定と一致するかを毎回確認することが唯一の防御になります。なおこの `UPDATE` は現在値に加算する相対的な更新なので、2回実行すると60増えてしまう（何度実行しても同じ結果にはならない）点にも注意してください。

---

## 問題 12: 論理削除を取り消す
- **目的**: メタカラムに `NULL` を明示的にセットして論理削除を取り消す方法を学び、「論理削除は元に戻せるが物理削除は戻せない」という運用上の差を体感する。

### 問題:
`product_id = 11` の「ゲーミングマウス」は 2023-09-20 に販売終了となりましたが、再入荷したため販売を再開することになりました。

**(1)** 更新前に、販売終了になっている商品（`deleted_at` に日時が入っている商品）を `SELECT` で確認してください。何件ありますか。

**(2)** 「ゲーミングマウス」の `deleted_at` を `NULL` に戻し、販売中の状態にしてください。

**(3)** 更新後、販売終了商品が 0 件になったこと、および出荷可能な商品（`deleted_at IS NULL AND stock_quantity > 0`）が 18 件から 19 件に増えたことを `SELECT` で確認してください。

**この問のSQLは `BEGIN;` … `ROLLBACK;` で囲んで実行してください。** 確定させると、この章より後の集計結果が教材と合わなくなります。

> **ヒント**: 列を「未設定」の状態に戻すには `SET 列名 = NULL` と書きます（`'NULL'` という文字列ではありません）。

### 解答:
```sql
BEGIN;

-- (1) 更新前の販売終了商品（1件: product_id=11）
SELECT product_id, product_name, deleted_at
FROM products_mst
WHERE deleted_at IS NOT NULL
ORDER BY product_id;

-- 出荷可能な商品（更新前は18件）
SELECT product_id, product_name, stock_quantity
FROM products_mst
WHERE deleted_at IS NULL
  AND stock_quantity > 0
ORDER BY product_id;

-- (2) 論理削除の取り消し → UPDATE 1
UPDATE products_mst
SET deleted_at = NULL
WHERE product_id = 11;

-- (3) 更新後の販売終了商品（0件になる）
SELECT product_id, product_name, deleted_at
FROM products_mst
WHERE deleted_at IS NOT NULL
ORDER BY product_id;

-- 出荷可能な商品（19件になる。product_id=11 が加わる）
SELECT product_id, product_name, stock_quantity
FROM products_mst
WHERE deleted_at IS NULL
  AND stock_quantity > 0
ORDER BY product_id;

ROLLBACK;   -- 販売再開を確定させずに捨てる（deleted_at は 2023-09-20 18:00:00+09 のまま）
```

### 期待結果:
| 確認内容 | 更新前 | 更新後 |
| :--- | ---: | ---: |
| 販売終了商品の件数 | 1 | 0 |
| 出荷可能な商品の件数 | 18 | 19 |

### 解説:
`SET 列名 = NULL` は「値を未設定に戻す」、つまりこの場合は **削除の取り消し** を意味します。もし `DELETE` で物理削除していたら、`order_details_trn` に残る渡辺 剛さんの購入履歴（`order_id = 7`）ごと消えてしまい、この復旧はできませんでした ―― これが実務で論理削除が好まれる最大の理由です。`WHERE` を書き忘れると全23商品が販売中に戻ってしまう点は、問題10と同じ注意が必要です。

---

## 問題 13: 商品名を条件にした UPDATE はなぜ危ないか
- **目的**: 一意でない列（商品名）を `UPDATE` の絞り込みキーにすると「余計な行まで更新される」「更新すべき行が漏れる」の両方が起きることを、実データで確認する。

### 問題:
`products_mst` テーブルに対して、2件の価格改定を行います。
**それぞれ、`UPDATE` を実行する前に必ず同じ `WHERE` 条件で `SELECT` を実行し、対象行を目で確認してください。**

**(1)** 「`SQL 入門` を 2,700 円に値上げする」という依頼を、`WHERE product_name = 'SQL 入門'` で実行してください。何件更新されましたか。それは意図した結果ですか。

**(2)** 「`国産はちみつ` を 1,300 円に値上げする」という依頼を、`WHERE product_name = '国産はちみつ'` で実行してください。何件更新されましたか。更新されずに取り残された商品はありませんか。

**(3)** (1) と (2) は、それぞれ何を `WHERE` 条件にするべきだったでしょうか。正しい `UPDATE` を書いてください。

**この問のSQLは `BEGIN;` … `ROLLBACK;` で囲んで実行してください。** 確定させると、この章より後の集計結果が教材と合わなくなります。

> **ヒント**: `product_name` は主キーではありません。同じ値の行が複数あってもかまわないし、見た目が似ていても文字列として別の値になっていることもあります。

### 解答:
```sql
BEGIN;

-- (1) 実行前の確認 → 2件ヒットする（product_id = 2 と 19）
SELECT product_id, product_name, price
FROM products_mst
WHERE product_name = 'SQL 入門'
ORDER BY product_id;

UPDATE products_mst
SET price = 2700.00
WHERE product_name = 'SQL 入門';
-- → UPDATE 2。誤って二重登録された product_id=19 まで値上げされてしまった

-- (2) 実行前の確認 → 1件しかヒットしない（product_id = 15 のみ）
SELECT product_id, product_name, price
FROM products_mst
WHERE product_name = '国産はちみつ'
ORDER BY product_id;

UPDATE products_mst
SET price = 1300.00
WHERE product_name = '国産はちみつ';
-- → UPDATE 1。product_id=20 は商品名が ' 国産はちみつ '（前後に半角スペース）
--   のため文字列として一致せず、値上げから漏れてしまった

-- (3) 正しい書き方 ―― 主キー（product_id）で指定する
-- (1) は product_id=2 だけが対象（19 は誤登録行なので値上げしてはいけない）
UPDATE products_mst
SET price = 2700.00
WHERE product_id = 2;

-- (2) は同一商品である product_id=15 と 20 の両方を対象にする
UPDATE products_mst
SET price = 1300.00
WHERE product_id IN (15, 20);

ROLLBACK;   -- 値上げを確定させずに捨てる（2・19 は 2500.00、15・20 は 1200.00 のまま）
```

### 期待結果:

商品名を `WHERE` にした場合（(1) と (2) を実行した直後の状態）

| product_id | product_name | 更新後の price | 意図どおりか |
| ---: | :--- | ---: | :--- |
| 2 | SQL 入門 | 2700.00 | 意図どおり |
| 19 | SQL 入門 | 2700.00 | 誤り。誤登録行まで値上げされた |
| 15 | 国産はちみつ | 1300.00 | 意図どおり |
| 20 | ` 国産はちみつ ` | 1200.00 | 誤り。更新されずに取り残された |

### 解説:
`product_name` には `UNIQUE` 制約がないため同じ商品名の行が複数存在でき（product_id 2 と 19）、逆に前後の空白が1つ違うだけで別の値になり一致しません（product_id 15 と 20）。「多すぎる更新」と「少なすぎる更新」は、どちらも「絞り込みキーが一意でない」という同じ原因から起きています。`UPDATE` / `DELETE` の `WHERE` には原則として主キーを使い、それができない場合は必ず同じ `WHERE` 条件で `SELECT` して対象件数を確認してから実行してください。
