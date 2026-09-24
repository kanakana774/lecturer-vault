# todo-app-api

Todo管理API。Java 21 / Spring Boot 3.4.1 / MyBatis / PostgreSQL 17。

## 設計書

設計書は `docs/` にある。実装の根拠はここから取る。

| 場所 | 中身 |
|---|---|
| `docs/00.環境構築/` | 環境構築手順 |
| `docs/01.要件定義/` | 要件定義書 |
| `docs/02.DB設計/` | DB定義書・DDL |
| `docs/03.API設計/` | OpenAPI・エラーコード表・プログラム設計書 |
| `docs/04.開発資料/` | コーディングガイド |
| `docs/実装計画.md` | 今回の作業の計画とテストケース一覧 |

設計書に書かれていないことに気づいたら、推測で埋めずに報告する。仕様の決定権は仕様管理者にある。
確認が取れた内容だけを、該当する設計書に反映する。

## アーキテクチャ

| 層 | 場所 | 責務 |
|---|---|---|
| Controller | `app/controller/` | リクエストの受け取りとレスポンスの組み立て |
| Service | `logic/service/` | 業務ロジック。`@Transactional` はここに置く |
| Mapper | `mapper/` ＋ `resources/.../mapper/*.xml` | SQL |

`entity/` `form/` `query/` `queryCondition/` `core/exception/` `util/` は既存のものに従う。

## コマンド

```bash
mvn test
mvn checkstyle:check
```

## テスト

参照実装 `src/test/java/jp/aevic/todo/app/controller/todo/TodoGetByIdTest.java` に合わせる。

- Controller 層の統合テスト。モックは使わず、HTTP リクエストから実 DB まで通す
- DBUnit（`@DatabaseSetup` / `@ExpectedDatabase`）を使う
- `@ExpectedDatabase` には `assertionMode = DatabaseAssertionMode.NON_STRICT_UNORDERED` を必ず付ける
- dataset は `src/test/resources/META-INF/dbunit/` 以下に、テストクラスと同じ階層で置く
- 期待値は設計書から取る。実装を見て期待値を決めない
- assert はレスポンスボディと DB の両方を見る
- テストは実行順に依存させない

## 作業の進め方

### 着手前に `docs/実装計画.md` を合意する

実装に入る前に、何を作るか・どこまでやるか・どうなれば完了かを `docs/実装計画.md` に書き、承認を得る。
テストケース一覧もここに含める。

ケース1件につき次を書く。

- 入力・事前状態・期待する結果
- 設計書のどこから来たかの根拠

期待する結果を断定できないケースは一覧に載せない。根拠が書けないものは仕様が決まっていないので、報告する。

### コミット単位

エンドポイント単位で刻む。1コミットの中では次の順に進める。

1. そのコミットで満たすケースを、`docs/実装計画.md` のケース一覧からテストに起こす
2. 実装前に `mvn test` を実行し、1 のテストが失敗することを確認する
3. 実装する。1 のテストは変えない。変える必要があると判断したら、変えずに理由を報告する
4. `mvn test` と `mvn checkstyle:check` を通してコミットする

取り消しのきかない操作（コミット・ファイル削除・DB 操作）は、実行前に承認を取る。

### コミットメッセージ

AI が書いた変更にはトレーラーを付ける。

```
Assisted-by: Claude Code
```

## 完了の定義（DoD）

すべての変更に共通の最低ライン。機能ごとの合格条件は `docs/実装計画.md` のケース一覧が持つ。

### 自動で判定する

- `mvn test` が通る
- `mvn checkstyle:check` が通る

### レビュー観点 — PR を出す前に一巡する

1. 一覧の件数に比例してクエリが増える書き方をしない（N+1）。`for` でも `stream` でも同じ
2. `e.getMessage()`・スタックトレース・SQL 断片・DB の制約名やテーブル名・設定値を、レスポンスに載せない。エラーレスポンスは共通例外に任せ、自前で組み立てない
3. Controller から Mapper を直接呼ばない。Service に HTTP の都合（ステータス・`ResponseEntity`）を持ち込まない
4. OpenAPI に定義のないフィールドをレスポンスに含めない
5. SQL はカラムを列挙する（`SELECT *` を使わない）
6. `docs/実装計画.md` で宣言した範囲外のファイルを変更しない。テーブル定義（DDL）を変更しない
7. `pom.xml` の依存を追加・変更しない
8. `@Transactional` を Service に置く。削除は子（`todo_tag`）→ 親（`todo`）の順にし、外部キー制約が無いことに依存しない
9. テストが仕様を検証している（→ テスト）

## スコープ外

性能（応答時間・スループット）とセキュリティ（認証・認可・脆弱性診断）は、このプロジェクトでは目標値を定義していない。
ただし N+1（観点1）と情報の露出（観点2・4）は観点に含まれるので対象。

確認していない範囲は、PR にそう書く。
