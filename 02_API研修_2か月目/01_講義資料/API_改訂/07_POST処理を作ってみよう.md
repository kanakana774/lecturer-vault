# POST 処理を作ってみよう

> [!abstract] この章が終わったら
> - この章の例を手本にして、**tag の登録（`POST /tags`）を自分で書ける**
> - Form・Controller・Entity・Service・Mapper の**それぞれに何を書くか**が分かる
> - 書いた API を Postman で叩いて、**201 と 400 が返ること**を確かめられる

ここからは実際にコードを書きます。
リクエストがどのクラスを通るかは `04_課題で作るものの全体像` §2 の図のとおりです。忘れていたら見返してください。

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

| カラム | 型 | 制約 | 登録する値 | どこから来るか |
| :--- | :--- | :--- | :--- | :--- |
| `SPORT_ID` | SERIAL | 主キー | 1 | **DB が自動採番** |
| `NAME` | varchar(20) | NOT NULL | サッカー | リクエスト |
| `PLAYER_COUNT` | integer | NOT NULL | 11 | リクエスト |
| `VERSION` | integer | NOT NULL | 0 | **自分で入れる**（§6） |

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
>
> XML をこのフォルダの下に置くのは、`application.properties` でそう決めてあるからです。
> ```properties
> mybatis.mapper-locations=classpath*:/META-INF/jp/aevic/todo/mapper/**/*.xml
> ```
> 別の場所に置くと MyBatis が見つけられず、実行時にエラーになります。

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

**上限の 20 のような数字は、自分で決めません。** API 設計書の 400 の条件に書いてあります。tag なら「1 文字以上 30 文字以内」です。

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

`version` の初期値はここでは入れません。「新しく登録したら 0 から始まる」は**業務のルール**なので Service に書きます（§6）。

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
    // 登録時の更新回数
    private static final int INITIAL_VERSION = 0;

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
        // 新規登録なので、更新回数は0から始める
        sportEntity.setVersion(INITIAL_VERSION);

        // INSERTすると、採番されたIDがsportEntityのsportIdに入る
        sportMapper.insert(sportEntity);
        return sportEntity.getSportId();
    }
}
```

### 6-1. 更新回数の初期値

`VERSION` カラムは NOT NULL で、DB 側に既定値がありません。**登録するときに自分で 0 を入れます。**

- **Service に書く** … 「新規登録は 0 から」は業務のルールです（`05_なぜクラスを分けるのか` §2）
- **`0` と直接書かず、定数にする** … コードの途中にいきなり出てくる数字は、読む人に意味が伝わりません。コーディングガイドでも禁止されています（マジックナンバー）

### 6-2. 採番された ID の受け取り方

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
tag なら 30 文字と 31 文字です。

---

## 9. 課題に取り組むときの注意

### 9-1. クラス名は、左から読んで絞り込めるように

`CreateSportForm` ではなく **`SportCreateForm`** です。
「スポーツの → 登録の → Form」と、左から読むほど対象が絞り込まれる順に並べます。
ファイルを名前順に並べたときに、同じ対象のクラスが固まるという利点もあります。

### 9-2. Form と Entity は `new` する

Controller・Service・Mapper は DI で受け取りますが、**Form と Entity は DI しません。** `@Component` なども付けません。

Spring が管理するインスタンスは、アプリ全体で 1 つだけです（`06_フレームワークとORマッパー` §3-3）。
Form や Entity は**リクエストのたびに中身が違う**ので、1 つを使い回すわけにいきません。

### 9-3. Javadoc の `@param` / `@return` には説明を書く

```java
 * @param sportCreateForm リクエストボディを詰めたForm   ← ○
 * @param sportCreateForm                                  ← ×（名前だけ）
```

名前だけだと、書いていないのと同じです。

### 9-4. 調べるときは、ツールの名前を入れる

その書き方が **Spring Boot・MyBatis・Java のどれの持ち物か**を考えて、その名前を検索語に入れます。
たとえば XML の書き方が分からないなら、「mybatis insert 自動採番」のように `mybatis` を入れないと出てきません。
