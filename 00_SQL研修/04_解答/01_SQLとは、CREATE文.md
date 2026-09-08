# 01章 演習 解答：SQLとは、CREATE文

**PostgreSQL 17 で実際に動かした結果を載せています。** この章で作る4つのテーブル（`customers_mst` / `products_mst` / `orders_trn` / `order_details_trn`）を、02章以降でそのまま使います。

この章は `CREATE TABLE` そのものが課題です。リセットしたいときは `DROP TABLE` で4つを落として（子の `order_details_trn` から先に）、もう一度作ってください。

---

## 問題 1: 4つのテーブルを設計して作成する
- **目的**: 要件からテーブル構造を起こし、データ型・NOT NULL・外部キー・論理削除カラムを自分で選択する設計力を養う。

### 問題:

以下の要件を満たすためのテーブルを作成する SQL を記述してください。

顧客情報:（customers_mst（顧客マスタ））
顧客ごとに一意の ID（customer_id） を割り当てる。
顧客の名前（customer_name）、uniqe なメールアドレス（email）、登録日（created_date）を記録する。
顧客が退会した場合、データを物理的に削除せず、論理的に削除した日時を記録する。（deleted_at）

商品情報:（products_mst（商品マスタ））
商品ごとに一意の ID（product_id） を割り当てる。
商品のカテゴリ（category）、名前（product_name）、価格（price）、在庫数（stock_quantity）を記録する。
商品の説明を自由に記述できるようにする。（memo）
販売終了となった商品は、論理的に削除した日時を記録する。（deleted_at）

注文情報:（orders_trn（注文トランザクション））
注文ごとに一意の ID を割り当てる。（order_id）
どの顧客（customer_id）が、いつ注文したかを記録する。（order_date）
注文がキャンセルされた場合、論理的に削除した日時を記録する。（deleted_at）
顧客情報テーブルとの関連付け（外部キー設定）を行う。（customer_id）

注文明細:（order_details_trn（注文明細トランザクション））
注文と商品の組み合わせで一意になるようにする。(order_id, product_id)
各注文に、どの商品が、いくつ含まれているかを記録する。（quantity）
注文の一部がキャンセルされた場合、論理的に削除した日時を記録する。（deleted_at）
注文情報テーブルおよび商品情報テーブルとの関連付け（外部キー設定）を行う。(order_id, product_id)

備考：
・データ型はどれがふさわしいか考えてみてください。（１００％正解はないので考える機会と思って、、、）
・not null 制約は適宜必要だと思った場合に追加してください。
・外部キーを使用し、テーブル間の関係を表現してください。

### 解答:
```sql
-- 顧客マスタ (customers_mst)
CREATE TABLE customers_mst (
customer_id SERIAL PRIMARY KEY,
customer_name VARCHAR(255) NOT NULL,
email VARCHAR(255) UNIQUE NOT NULL,
created_date DATE NOT NULL,
deleted_at TIMESTAMPTZ -- これは所謂メタカラム（論理削除のフラグ替わりなので正確な時間をTIMESTAMPTZで記録する意図）
);

-- 商品マスタ (products_mst)
CREATE TABLE products_mst (
product_id SERIAL PRIMARY KEY,
category VARCHAR(100) NOT NULL,
product_name VARCHAR(255) NOT NULL,
price NUMERIC(10, 2) NOT NULL,
stock_quantity INTEGER NOT NULL,
memo TEXT,
deleted_at TIMESTAMPTZ
);

-- 注文トランザクション (orders_trn)
CREATE TABLE orders_trn (
order_id SERIAL PRIMARY KEY,
customer_id INTEGER NOT NULL,
order_date DATE NOT NULL,
deleted_at TIMESTAMPTZ,
FOREIGN KEY (customer_id) REFERENCES customers_mst(customer_id)
);

-- 注文明細トランザクション (order_details_trn)
CREATE TABLE order_details_trn (
order_id INTEGER NOT NULL,
product_id INTEGER NOT NULL,
quantity INTEGER NOT NULL,
deleted_at TIMESTAMPTZ,
PRIMARY KEY (order_id, product_id),
FOREIGN KEY (order_id) REFERENCES orders_trn(order_id),
FOREIGN KEY (product_id) REFERENCES products_mst(product_id)
);

```

---

## 追加課題（ここから先は任意）

**問題 1 まで**が必須です。ここから先は、早く終わった人・もっと設計を考えたい人向けです。題材が変わり、図書館の貸出システムになります。

---

## 問題 2: 基本設計（1対多の関係）
- **目的**: 1対多のリレーションを、主キーと外部キー制約で表現する。

### 問題:

まずはシンプルな要件でテーブルを設計・作成してください。

**【要件】**
1.  **著者（authors）**: 名前、生年月日を持つ。
2.  **書籍（books）**: タイトル、出版年を持つ。著者は**主著者が必ず1名**紐づく。
3.  **利用者（users）**: 名前、メールアドレス、登録日を持つ。メールアドレスは重複してはならない。
4.  **貸出履歴（loans）**: 「どの本」を「誰」が「いつ借りたか」を記録する。返却日も管理するが、貸出中は空（NULL）となる。

**【技術制約】**
*   主キーは自動採番（Identity column）を使用すること。
*   外部キー制約を適切に設定すること。

### 解答:
```sql
-- PostgreSQL モダン版
-- テーブルの初期化（再実行用）
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS authors;

-- 1. 著者テーブル
CREATE TABLE authors (
    author_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    birth_date DATE
);

-- 2. 書籍テーブル
CREATE TABLE books (
    book_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    publish_year SMALLINT, -- 年のみ管理する場合は整数型が適切
    author_id INT NOT NULL, -- 外部キー
    CONSTRAINT fk_books_author FOREIGN KEY (author_id) REFERENCES authors(author_id)
);

-- 3. 利用者テーブル
CREATE TABLE users (
    user_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE, -- 重複不可
    registered_date DATE DEFAULT CURRENT_DATE
);

-- 4. 貸出履歴テーブル
CREATE TABLE loans (
    loan_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id INT NOT NULL,
    user_id INT NOT NULL,
    loan_date DATE NOT NULL DEFAULT CURRENT_DATE,
    return_date DATE,
    -- 外部キー制約
    CONSTRAINT fk_loans_book FOREIGN KEY (book_id) REFERENCES books(book_id),
    CONSTRAINT fk_loans_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    -- 返却日は貸出日以降でなければならないチェック制約
    CONSTRAINT check_return_date CHECK (return_date >= loan_date)
);

-- サンプルデータ
INSERT INTO authors (name, birth_date) VALUES
('村上 春樹', '1949-01-12'),
('東野 圭吾', '1958-02-04');

INSERT INTO books (title, publish_year, author_id) VALUES
('ノルウェイの森', 1987, 1),
('白夜行', 1999, 2);

INSERT INTO users (name, email) VALUES
('佐藤 太郎', 'taro.sato@example.com'),
('鈴木 花子', 'hanako.suzuki@example.com');

INSERT INTO loans (book_id, user_id, loan_date, return_date) VALUES
(1, 1, '2025-08-20', '2025-09-01'),
(2, 2, '2025-09-01', NULL); -- まだ返却していない
```

---

## 問題 3: 発展設計（多対多への変更）
- **目的**: 中間テーブルを導入して多対多を表現し、既存の設計を安全に変更する手順を理解する。

### 問題:

**【追加要件】**
「1冊の本を複数の著者が執筆する（共著）」ケースに対応できるように設計を変更してください。
例：「Good Omens」という本は、ニール・ゲイマンとテリー・プラチェットの2人が著者です。

**【課題】**
現在の `books` テーブルにある `author_id` カラムでは、1つのIDしか保持できないため不適切です。これを解決するための**中間テーブル**を作成し、既存のテーブル定義を修正してください。

### 解答:
```sql
-- 多対多の実装（解説: `books` テーブルから `author_id` を削除し、新しく `book_authors` テーブルを作成して紐付けを行います。）
-- 既存データの退避が必要な場合は別途考慮が必要ですが、ここではDDLの変更のみ示します

-- 1. booksテーブルから author_id を削除
-- (注: 依存する外部キー制約がある場合、先に制約を削除する必要があります)
ALTER TABLE books DROP COLUMN author_id CASCADE;

-- 2. 中間テーブルの作成
CREATE TABLE book_authors (
    book_id INT NOT NULL,
    author_id INT NOT NULL,
    role VARCHAR(50), -- 役割（任意項目：共著、翻訳など）
    PRIMARY KEY (book_id, author_id), -- 複合主キー（同じペアの重複を防ぐ）
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);

-- データの登録例（共著の場合）
-- まず著者と本を登録
INSERT INTO authors (name) VALUES ('ニール・ゲイマン'), ('テリー・プラチェット');
INSERT INTO books (title, publish_year) VALUES ('グッド・オーメンズ', 1990);

-- 中間テーブルで紐付け (IDは環境依存ですが、仮に 3, 4 と 3 だとします)
-- book_id=3 を author_id=3 と author_id=4 が書いた
INSERT INTO book_authors (book_id, author_id, role) VALUES
(3, 3, '共著'),
(3, 4, '共著');
```

### 解説:

設計を考えるうえでの着眼点をまとめます。

#### 1. データ型の選び方
*   **`SERIAL` vs `IDENTITY`**:
    *   古い解説記事では `SERIAL` がよく使われますが、標準SQL準拠の `GENERATED ALWAYS AS IDENTITY` の方が、権限管理や予期せぬID書き換えを防げるため推奨されます。
*   **`DATE` vs `INT` (publish_year)**:
    *   「出版日」まで厳密に分かるなら `DATE` ですが、古い本や雑誌などは「年」や「月」までしか分からないことが多いです。`DATE` 型に無理やり `YYYY-01-01` を入れると、「1月1日出版」なのか「日付不明」なのか区別がつかなくなります。要件に応じて型を選定することが重要です。

#### 2. 正規化と中間テーブル
*   ステップ1の状態は、著者と本が1対多（第2正規形相当）ですが、ステップ2で多対多に対応することで、より柔軟な設計（第3正規形や関連エンティティの切り出し）になります。
*   **「なぜ配列型（Array）を使わないのか？」** という質問が出ることがあります（PostgreSQLは配列型が使えるため）。
    *   回答例：「著者IDを配列 `[1, 2]` で持つことも可能ですが、結合（JOIN）して検索する際のパフォーマンスが悪化したり、外部キー制約（著者が削除されたら検知する）が効かなくなったりするため、リレーショナルデータベースでは中間テーブルを使うのが定石です。」

#### 3. データの整合性（Constraints）
*   解答例に入れた `CHECK (return_date >= loan_date)` のように、DBレベルで「未来に返却することはあっても、貸出日より過去に返却することはありえない」といったルールを守らせることができます。
*   **発展課題**: 「現在貸出中の本（`return_date IS NULL`）は、新たに貸出できないようにするには？」
    *   答え：PostgreSQLの **排他制約 (Exclusion Constraint)** や **部分ユニークインデックス (Partial Unique Index)** を使います。
    *   例: `CREATE UNIQUE INDEX idx_book_loaning ON loans (book_id) WHERE return_date IS NULL;`
    *   これにより、返却されていない本に対して新しい貸出データをINSERTしようとするとエラーになります。

#### 4. 第3正規形（3NF）への正規化

**第3正規形のルール（超要約）**：
> 「非キー属性は、主キー**だけ**に依存しなければならない。（主キー以外の項目に依存してはいけない）」

もっと噛み砕くと、**「Aが決まればBが決まる、Bが決まればCが決まる（推移的関数従属）」という関係がある場合、Cは別テーブルに追い出しなさい**、ということです。

##### ❌ ダメな設計（第2正規形までは満たしているが、第3正規形ではない）

もし、書籍テーブルを以下のように設計したらどうなるでしょうか？

```sql
-- 悪い設計の books テーブル
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(200),
    publish_year INT,
    author_name VARCHAR(100),       -- 著者の名前
    author_birth_date DATE,         -- 著者の誕生日（！？）
    publisher_name VARCHAR(100),    -- 出版社名
    publisher_address VARCHAR(200)  -- 出版社住所（！？）
);
```

**【何が問題か？】**
1.  **データの重複**: 村上春樹の本が10冊あれば、`author_birth_date` も10回同じ日付が保存されます。
2.  **更新時異常**: 出版社が引っ越して `publisher_address` が変わった場合、その出版社の本を**全件更新**しないと、古い住所と新しい住所が混在してしまいます。

**【依存関係の分析】**
*   `book_id` (主キー) が決まれば `title` が決まる → **OK**
*   `book_id` が決まれば `publisher_name` が決まる → **OK**
*   しかし、`publisher_address` は `book_id` ではなく、**`publisher_name`（主キー以外）に依存** している。
    *   これが **「推移的関数従属」** です。

##### ✅ 第3正規形への修正

「主キー以外に依存している項目」を切り離して、独立したテーブルにします。

1.  **著者情報** は `authors` テーブルへ切り出す。
2.  **出版社情報** は `publishers` テーブルへ切り出す。
3.  `books` テーブルには、それぞれの **ID（外部キー）** だけを残す。

これにより、住所変更があっても `publishers` テーブルの1行を更新するだけで完了します。これが第3正規化のメリットです。


#### 5. 関連エンティティ（Associative Entity）の切り出し

これは「多対多」の関係を解消する際に登場する概念です。
単なる「つなぎ」のテーブルではなく、**その「関係そのもの」が情報を持つようになったもの**を「関連エンティティ」と呼びます。
##### ステップ A：単なる中間テーブル（Junction Table）

著者が複数いる場合、`books` と `authors` の間に `book_authors` を作ります。

```sql
-- 単なる「つなぎ」の状態
CREATE TABLE book_authors (
    book_id INT,
    author_id INT,
    PRIMARY KEY (book_id, author_id)
);
```
これでも「多対多」は解決できています。しかし、実務ではこれだけでは足りないことがよくあります。

##### ステップ B：関連エンティティへの進化

現実世界では、「関係」自体に属性（追加情報）が発生します。

*   **Q:** この著者は「主著」ですか？「監修」ですか？「翻訳」ですか？
*   **Q:** 著者が複数いる場合、表紙に名前が出る「順番」はどうしますか？
*   **Q:** 印税の配分率は？

これらの情報は、`books`（本そのもの）の情報でもないし、`authors`（人間そのもの）の情報でもありません。**「執筆契約（著者が本を書いた）」という事実に対する情報**です。
そこで、中間テーブルを拡張します。

```sql
-- 関連エンティティ化したテーブル
CREATE TABLE book_authors (
    book_id INT REFERENCES books(book_id),
    author_id INT REFERENCES authors(author_id),
    
    -- 関係に付随する属性
    role VARCHAR(50) NOT NULL DEFAULT 'Author', -- 役割 (例: Translator, Illustrator)
    display_order SMALLINT DEFAULT 1,           -- 表示順 (1番目が主著者など)
    royalty_percent DECIMAL(5, 2),              -- 印税率
    
    PRIMARY KEY (book_id, author_id)
);
```
