# POST 処理を作ってみよう

> [!abstract] この章が終わったら
> - この章の例を手本にして、**tag の登録（`POST /tags`）を自分で書ける**
> - Form・Controller・Entity・Service・Mapper の**それぞれに何を書くか**が分かる
> - 書いた API を Postman で叩いて、**201 と 400 が返ること**を確かめられる
> - エラーが出たときに、**ログを読んで原因の場所を絞り込める**

ここからは実際にコードを書きます。
リクエストがどのクラスを通るかは `04_課題で作るものの全体像` §2 の図のとおりです。忘れていたら見返してください。

> [!warning] この章のコードは、そのまま写しても動きません
> **わざと、いくつか罠を仕込んであります。** 写して動かすとエラーになります。
>
> この先の課題（GET・PUT・DELETE）は、手本無しで自分で書きます。そのときにはエラーを読んで自分で直す力が要ります。
> この章はその練習です。
>
> エラーが出たら §9 の手順で読み、調べて、直してください。
> **15 分調べても進まなければ、講師に聞いてください。** 聞き方は §9-5 にあります。

---

## 1. この章の例：スポーツの登録

例として使うのは **tag ではなく「スポーツの登録」** です。
答えを写すのではなく、**スポーツを tag に置き換えながら**書いてください。
置き換えるときに「この行は何のためにあるのか」を考えることになります。それが狙いです。

### 1-1. 送られてくるリクエスト

```
POST http://localhost:8080/sports
```

```json
{
  "name": "サッカー",
  "playerCount": 11
}
```

### 1-2. 登録先のテーブル

`SPORT` テーブルに、次の値で 1 行登録します。

| カラム | 型 | 制約 | 登録する値 |
| :--- | :--- | :--- | :--- |
| `SPORT_ID` | SERIAL | 主キー | 1（DB が自動採番） |
| `NAME` | varchar(20) | NOT NULL | サッカー |
| `PLAYER_COUNT` | integer | NOT NULL | 11 |
| `VERSION` | integer | NOT NULL | 0 |

### 1-3. 返すレスポンス

登録に成功したら **`201 Created`** を返し、登録したものを取得できる URL を **`Location` ヘッダー**に入れます。
ボディは空です。

```
HTTP/1.1 201
Location: http://localhost:8080/sports/1
```

入力に誤りがあれば **`400 Bad Request`** を返します。何を誤りとするかは API 設計書に書いてあります。

---

## 2. 作るファイルと置き場所

雛形には、置き場所になるフォルダが**すでに用意されています**（中に `.gitkeep` だけが入っているフォルダ）。
tag のファイルは `tag` のフォルダに置きます。

| 作るもの | スポーツの例 | 置き場所（`src/main/java/jp/aevic/todo/` の下） |
| :--- | :--- | :--- |
| Form | `SportCreateForm` | `form/sport/` |
| Entity | `SportEntity` | `entity/sport/` |
| Controller | `SportController` | `app/controller/sport/` |
| Service | `SportService` | `logic/service/sport/` |
| Mapper インターフェース | `SportMapper` | `mapper/sport/` |
| Mapper XML | `SportMapper.xml` | `src/main/resources/META-INF/jp/aevic/todo/mapper/` |

> [!note]- tag の Mapper XML は雛形にもうある
> `src/main/resources/META-INF/jp/aevic/todo/mapper/TagMapper.xml` が、中身が空の状態で用意されています。
> 新しく作らず、ここに SQL を書き足してください。

---

## 3. Form：リクエストを受け取る箱

```java
package jp.aevic.todo.form.sport;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * スポーツの登録で受け取るForm
 */
public class SportCreateForm {
    // スポーツ名
    @NotBlank
    @Size(max = 20)
    private String name;

    // 1チームの人数
    @NotNull
    private Integer playerCount;

    // getter / setter は省略
}
```

フィールド名は、**リクエストの JSON のキー名と揃えます。** 揃っていれば、JSON から Form への詰め替えは Spring Boot がやってくれます。

付けたアノテーションは入力チェックの**目印**です。チェックそのものは、Controller の `@Validated`（§5）が動かします。

| アノテーション | 意味 | 違反したとき |
| :--- | :--- | :--- |
| `@NotBlank` | 文字列が null・空文字・空白だけ、のどれでもない | 400 |
| `@Size(max = 20)` | 文字数が 20 以下 | 400 |
| `@NotNull` | null でない | 400 |

**上限の 20 のような数字は、自分で決めません。** API 設計書の 400 の条件に書いてあります。

`@NotBlank` の時点で空文字は通らないので、`@Size` に `min = 1` は要りません。

> ⚠️ **数値の項目は `int` でなく `Integer` で受ける**
> `int` で受けると、`@NotNull` が付いていても**絶対に 400 になりません。**
> `int` は null になれないので、キーが無いときは `0` が入ります。null になる瞬間が無いので、チェックが素通りします。
> 付けたアノテーションが効かないのに、コンパイルも通り、正常系の動作確認も全部通ります。**見た目では気づけません。**
> **getter / setter の型も `Integer` にそろえます。** フィールドだけ直しても、セッターが `int` のままなら同じことが起きます。

---

## 4. Entity：テーブルの 1 行を表す箱

```java
package jp.aevic.todo.entity.sport;

/**
 * SPORTテーブルの1行を表すEntity
 */
public class SportEntity {
    // スポーツID
    private Integer sportId;
    // スポーツ名
    private String name;
    // 1チームの人数
    private Integer playerCount;
    // 更新回数
    private Integer version;

    // getter / setter は省略
}
```

フィールドは**テーブルのカラムと 1 対 1** にします。
カラム名 `PLAYER_COUNT` とフィールド名 `playerCount` は、MyBatis が自動で対応づけてくれます（`application.properties` の `map-underscore-to-camel-case=true`）。

Form と Entity では、**何ごとに 1 つ作るか**が違います。

| | Form | Entity |
| :--- | :--- | :--- |
| 何に合わせるか | リクエスト | テーブル |
| 何ごとに作るか | **リクエストごと**（登録用・更新用…） | **テーブルごと**（1 テーブルに 1 つ） |
| スポーツの例 | `SportCreateForm`、`SportUpdateForm` … | `SportEntity` だけ |

登録でも更新でも取得でも、`SPORT` テーブルを扱うなら `SportEntity` を使います。
`SportCreateEntity` のように、**リクエストごとに Entity を分けません。**

---

## 5. Controller：受け取って、詰め替えて、返す

```java
package jp.aevic.todo.app.controller.sport;

import java.net.URI;
import jp.aevic.todo.entity.sport.SportEntity;
import jp.aevic.todo.form.sport.SportCreateForm;
import jp.aevic.todo.logic.service.sport.SportService;
import jp.aevic.todo.util.LocationUtil;
import jp.aevic.todo.util.statics.CreatedLocationPaths;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * スポーツに関するコントローラー
 */
@RestController
@RequestMapping(path = "/sports", produces = MediaType.APPLICATION_JSON_VALUE)
public class SportController {
    // 依存クラス
    private final SportService sportService;
    private final LocationUtil locationUtil;

    /**
     * コンストラクタ
     *
     * @param sportService スポーツのサービス
     * @param locationUtil Locationヘッダーに入れるURLを作るUtil
     */
    public SportController(SportService sportService, LocationUtil locationUtil) {
        this.sportService = sportService;
        this.locationUtil = locationUtil;
    }

    /**
     * スポーツの登録
     *
     * @param sportCreateForm リクエストボディを詰めたForm
     * @return 201 Created と、登録したスポーツを取得できるURL
     */
    @PostMapping
    public ResponseEntity<Void> create(@RequestBody @Validated SportCreateForm sportCreateForm) {
        // FormからEntityに詰め替える
        SportEntity sportEntity = new SportEntity();
        sportEntity.setName(sportCreateForm.getName());
        sportEntity.setPlayerCount(sportCreateForm.getPlayerCount());

        // 登録して、採番されたIDを受け取る
        Integer sportId = sportService.create(sportEntity);

        // 登録したスポーツを取得できるURLをLocationヘッダーに入れて返す
        URI location = locationUtil.create(CreatedLocationPaths.SPORTS, sportId);
        return ResponseEntity.created(location).build();
    }
}
```

### 5-1. アノテーション

| アノテーション | 付ける先 | 意味 |
| :--- | :--- | :--- |
| `@RestController` | クラス | Controller として Spring に管理してもらう（`06_フレームワークとORマッパー` §3） |
| `@RequestMapping(path = "/sports")` | クラス | `/sports` へのリクエストをこのクラスで受ける |
| `@PostMapping` | メソッド | そのうち POST をこのメソッドで受ける |
| `@RequestBody` | 引数 | リクエストボディの JSON を Form に詰める |
| `@Validated` | 引数 | Form に付けた目印（`@NotBlank` など）でチェックする。違反があればメソッドの中に入る前に 400 が返る |

`@RequestMapping` の `produces` は「この Controller は JSON を返す」という宣言です。雛形の書き方に合わせて付けておきます。

### 5-2. メソッドの中でやること

**やるのは 3 つだけです。**

1. Form から Entity に詰め替える
2. Service を呼ぶ
3. レスポンスを作って返す

### 5-3. Location ヘッダーを作る

URL を作る `LocationUtil` と、パスを持つ `CreatedLocationPaths` は**雛形に用意されています。** 自分では作りません。

```java
URI location = locationUtil.create(CreatedLocationPaths.SPORTS, sportId);
// → http://localhost:8080/sports/1
```

`CreatedLocationPaths` には、tag 用のパスもすでに入っています。

```java
TAG("tags/{tagId}"),
```

`{tagId}` の部分に、第 2 引数の ID が入ります。

### 5-4. 戻り値は `ResponseEntity<Void>`

`<>` の中には**ボディの型**を書きます。201 はボディを返さないので `Void` です。
`ResponseEntity<String>` と書いても動きますが、「文字列を返す」と読めてしまいます。実際の中身と合いません。

---

## 6. Service：業務のルールを書いて、Mapper を呼ぶ

```java
package jp.aevic.todo.logic.service.sport;

import jp.aevic.todo.entity.sport.SportEntity;
import jp.aevic.todo.mapper.sport.SportMapper;
import org.springframework.stereotype.Service;

/**
 * スポーツに関するサービス
 */
@Service
public class SportService {
    // 依存クラス
    private final SportMapper sportMapper;

    /**
     * コンストラクタ
     *
     * @param sportMapper スポーツのMapper
     */
    public SportService(SportMapper sportMapper) {
        this.sportMapper = sportMapper;
    }

    /**
     * スポーツの登録
     *
     * @param sportEntity 登録するスポーツ
     * @return 採番されたスポーツID
     */
    public Integer create(SportEntity sportEntity) {
        // INSERTすると、採番されたIDがsportEntityのsportIdに入る
        sportMapper.insert(sportEntity);
        return sportEntity.getSportId();
    }
}
```

### 6-1. 採番された ID の受け取り方

`sportMapper.insert(...)` は何も返しません（`void`）。それでも、次の行で ID を取り出せます。

```java
sportMapper.insert(sportEntity);        // 呼ぶ前：sportId は null
return sportEntity.getSportId();        // 呼んだ後：DB が採番した値が入っている
```

**渡した Entity に、MyBatis が ID を書き込んでくれる**からです。その設定は XML に書きます（§7-2）。

---

## 7. Mapper：SQL を書く

### 7-1. インターフェース

```java
package jp.aevic.todo.mapper.sport;

import jp.aevic.todo.entity.sport.SportEntity;
import org.apache.ibatis.annotations.Mapper;

/**
 * SPORTテーブルを操作するMapper
 */
@Mapper
public interface SportMapper {
    /**
     * スポーツの登録
     *
     * @param sportEntity 登録するスポーツ。登録後、sportIdに採番されたIDが入る
     */
    void insert(SportEntity sportEntity);
}
```

実装クラスは書きません。MyBatis が用意します（`06_フレームワークとORマッパー` §2）。

### 7-2. XML

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper
        PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="jp.aevic.todo.mapper.sport.SportMapper">

    <insert id="insert" parameterType="jp.aevic.todo.entity.sport.SportEntity"
            useGeneratedKeys="true" keyProperty="sportId">
        INSERT INTO SPORT (
            NAME,
            PLAYER_COUNT,
            VERSION
        ) VALUES (
            #{name},
            #{playerCount},
            #{version}
        )
    </insert>

</mapper>
```

| 書く場所 | 意味 |
| :--- | :--- |
| `namespace` | どの Mapper インターフェースの SQL か（パッケージ名から書く） |
| `<insert id="insert">` | インターフェースの**どのメソッド**の SQL か。メソッド名と一致させる |
| `parameterType` | 受け取る引数の型（パッケージ名から書く） |
| `useGeneratedKeys="true"` | DB が採番した ID を受け取る |
| `keyProperty="sportId"` | 受け取った ID を、引数の Entity の**どのフィールド**に入れるか |
| `#{name}` | 引数の Entity の `name` の値をここに入れる |

- **カラムは省略せずに並べます。** `INSERT INTO SPORT VALUES (...)` と書くと、テーブルのカラムの順番が変わったときに黙って別のカラムに入ります
- `SPORT_ID` は書きません。DB が採番します

---

## 8. 動かして確かめる

アプリを起動して、Postman から送ります。

| 送るもの | 期待する結果 |
| :--- | :--- |
| 正しいボディ | **201**。`Location` ヘッダーに `http://localhost:8080/sports/1` |
| `name` が無い／空文字／空白だけ | 400 |
| `name` が 21 文字 | 400 |
| `playerCount` が無い | 400 |

201 が返ったら、**DB にも入っているか**を SQL で確認します。

```sql
SELECT * FROM SPORT;
```

```
 sport_id |   name   | player_count | version
----------+----------+--------------+---------
        1 | サッカー |           11 |       0
```

**境目の値も試します。** `name` が 20 文字なら 201、21 文字なら 400 になるはずです。
tag の境目がいくつかは、API 設計書から自分で読み取ってください。

---

## 9. エラーが出たら

### 9-1. 500 が返ったら、Postman ではなくコンソールを見る

500 が返っても、Postman に届くのはこれだけです。

```json
{"title":"INTERNAL_SERVER_ERROR","status":500,"code":"internal-server-error.unexpected","message":"Internal Server Error Unexpected."}
```

**ここには原因が書いてありません。** 利用者に内部の事情を見せないように、アプリがわざと伏せています。
原因は、`mvn spring-boot:run` を実行した**ターミナル**に出ています。

400 のときも同じです。どの項目が引っかかったかは、ターミナルのログで確かめます。

### 9-2. スタックトレースを読む

エラーが起きると、ターミナルに数百行のログが出ます。これを**スタックトレース**と言います。
全部読む必要はありません。**見る場所は 3 つだけ**です。

実際のログから、見る場所だけを抜き出すとこうなります（`keyProperty` を書き間違えたとき）。

```
ERROR ... MyExceptionLogger : URI: /sports, method: POST, ... Exception: org.mybatis.spring.MyBatisSystemException, ...

org.mybatis.spring.MyBatisSystemException:                                   ← ① 何が起きたか
	at org.mybatis.spring....                                                    （ライブラリの行が続く）
	at jp.aevic.todo.logic.service.sport.SportService.create(SportService.java:38)       ← ② 自分のコード
	at jp.aevic.todo.app.controller.sport.SportController.create(SportController.java:52)
	at org.springframework....                                                   （100 行以上続く）
	...
Caused by: org.apache.ibatis.executor.ExecutorException: Error getting generated key ...
	...
Caused by: org.apache.ibatis.executor.ExecutorException:
    No setter found for the keyProperty 'tagId' in 'jp.aevic.todo.entity.sport.SportEntity'.   ← ③ 根本の原因
```

| # | 見る場所 | 読み取れること |
| :--- | :--- | :--- |
| ① | 先頭の例外名 | どの道具（Spring・MyBatis・DB…）の中で起きたか |
| ② | `at jp.aevic.todo` で始まる行 | **自分のコードのどの行**から呼んだときに起きたか。ファイル名と行番号が付いている |
| ③ | **一番下の `Caused by:`** | 本当の原因。上の例外は、これを包み直したもの |

**③ から読みます。** たいていは、原因がそのまま英語で書いてあります。
`at org.springframework...` のような**ライブラリの行は読み飛ばして**かまいません。

> [!note]- メッセージが日本語と英語で混ざることがある
> DB（PostgreSQL）が返すメッセージは、DB の設定によって日本語になったり英語になったりします。
> 検索するときは英語のほうが情報が多いので、英語の部分を使ってください。

### 9-3. 調べる

1. **③ のメッセージをそのまま検索する。** ただし `jp.aevic.todo...` のような自分のプロジェクトの名前や、値の部分は外す
2. **道具の名前を入れる。** そのエラーが Spring Boot・MyBatis・PostgreSQL・Java のどれの持ち物かを ① から判断して、検索語に入れる
   （例：`mybatis No setter found for the keyProperty`）
3. **② の行を開いて、そこで渡している値を確かめる**

### 9-4. 値の中身を見る（デバッガ）

「たぶんこの値が入っているはず」を、**推測のままにしない**ことが大事です。
VS Code のデバッガで止めて、変数の中身を見ます。手順は `06.参考資料/デバッグ方法.md` にあります。

- **止める場所は ② の行**（エラーが起きる直前）
- そこで、**渡そうとしている Entity の各フィールドに何が入っているか**を見る
- 期待していた値と違うフィールドがあれば、そこが原因の入口

### 9-5. 講師に聞くとき

次の 4 つを揃えてから聞いてください。**揃える途中で自己解決することも多いです。**

| | 例 |
| :--- | :--- |
| 何をしたか | `POST /tags` に `{"name": "仕事"}` を送った |
| 何を期待したか | 201 が返る |
| 実際どうなったか | 500 が返った。ログの一番下の `Caused by:` は「〜」 |
| 何を試したか | 「〜」で検索して〜を見た。デバッガで止めたら `name` には値が入っていた |

「動きません」だけだと、講師は同じことを 1 から聞き直すことになります。

---

## 10. 課題に取り組むときの注意

### 10-1. クラス名は、左から読んで絞り込めるように

`CreateSportForm` ではなく **`SportCreateForm`** です。
「スポーツの → 登録の → Form」と、左から読むほど対象が絞り込まれる順に並べます。
ファイルを名前順に並べたときに、同じ対象のクラスが固まるという利点もあります。

### 10-2. Form と Entity は `new` する

Controller・Service・Mapper は DI で受け取りますが、**Form と Entity は DI しません。** `@Component` なども付けません。

Spring が管理するインスタンスは、アプリ全体で 1 つだけです（`06_フレームワークとORマッパー` §3-3）。
Form や Entity は**リクエストのたびに中身が違う**ので、1 つを使い回すわけにいきません。

### 10-3. Javadoc の `@param` / `@return` には説明を書く

```java
 * @param sportCreateForm リクエストボディを詰めたForm   ← ○
 * @param sportCreateForm                                  ← ×（名前だけ）
```

名前だけだと、書いていないのと同じです。
