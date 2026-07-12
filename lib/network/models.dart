import 'package:pixes/appdata.dart';

class Account {
  String accessToken;
  String refreshToken;
  final User user;

  Account(this.accessToken, this.refreshToken, this.user);

  Account.fromJson(Map<String, dynamic> json)
      : accessToken = json['access_token'],
        refreshToken = json['refresh_token'],
        user = User.fromJson(json['user']);

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user': user.toJson()
      };
}

class User {
  String profile;
  final String id;
  String name;
  String account;
  String email;
  bool isPremium;

  User(this.profile, this.id, this.name, this.account, this.email,
      this.isPremium);

  User.fromJson(Map<String, dynamic> json)
      : profile = json['profile_image_urls']['px_170x170'],
        id = json['id'],
        name = json['name'],
        account = json['account'],
        email = json['mail_address'],
        isPremium = json['is_premium'];

  Map<String, dynamic> toJson() => {
        'profile_image_urls': {'px_170x170': profile},
        'id': id,
        'name': name,
        'account': account,
        'mail_address': email,
        'is_premium': isPremium
      };
}

class UserDetails {
  final int id;
  final String name;
  final String account;
  final String avatar;
  final String comment;
  bool isFollowed;
  final bool isBlocking;
  final String? webpage;
  final String gender;
  final String birth;
  final String region;
  final String job;
  final int totalFollowUsers;
  final int myPixivUsers;
  final int totalIllusts;
  final int totalMangas;
  final int totalNovels;
  final int totalIllustBookmarks;
  final String? backgroundImage;
  final String? twitterUrl;
  final bool isPremium;
  final String? pawooUrl;

  UserDetails(
      this.id,
      this.name,
      this.account,
      this.avatar,
      this.comment,
      this.isFollowed,
      this.isBlocking,
      this.webpage,
      this.gender,
      this.birth,
      this.region,
      this.job,
      this.totalFollowUsers,
      this.myPixivUsers,
      this.totalIllusts,
      this.totalMangas,
      this.totalNovels,
      this.totalIllustBookmarks,
      this.backgroundImage,
      this.twitterUrl,
      this.isPremium,
      this.pawooUrl);

  UserDetails.fromJson(Map<String, dynamic> json)
      : id = json['user']['id'],
        name = json['user']['name'],
        account = json['user']['account'],
        avatar = json['user']['profile_image_urls']['medium'],
        comment = json['user']['comment'],
        isFollowed = json['user']['is_followed'],
        isBlocking = json['user']['is_access_blocking_user'],
        webpage = json['profile']['webpage'],
        gender = json['profile']['gender'],
        birth = json['profile']['birth'],
        region = json['profile']['region'],
        job = json['profile']['job'],
        totalFollowUsers = json['profile']['total_follow_users'],
        myPixivUsers = json['profile']['total_mypixiv_users'],
        totalIllusts = json['profile']['total_illusts'],
        totalMangas = json['profile']['total_manga'],
        totalNovels = json['profile']['total_novels'],
        totalIllustBookmarks = json['profile']['total_illust_bookmarks_public'],
        backgroundImage = json['profile']['background_image_url'],
        twitterUrl = json['profile']['twitter_url'],
        isPremium = json['profile']['is_premium'],
        pawooUrl = json['profile']['pawoo_url'];
}

class Author {
  final int id;
  final String name;
  final String account;
  final String avatar;
  bool isFollowed;

  Author(this.id, this.name, this.account, this.avatar, this.isFollowed);
}

class Tag {
  final String name;
  final String? translatedName;

  const Tag(this.name, this.translatedName);

  @override
  String toString() {
    return "$name${translatedName == null ? "" : "($translatedName)"}";
  }

  @override
  bool operator ==(Object other) {
    if (other is Tag) {
      return name == other.name;
    }
    return false;
  }

  @override
  int get hashCode => name.hashCode;

  static Tag fromJson(Map<String, dynamic> json) {
    return Tag(json['name'] ?? "", json['translated_name']);
  }
}

class IllustImage {
  final String squareMedium;
  final String medium;
  final String large;
  final String original;

  const IllustImage(this.squareMedium, this.medium, this.large, this.original);
}

class Illust {
  final int id;
  final String title;
  final String type;
  final List<IllustImage> images;
  final String caption;
  final int restrict;
  final Author author;
  final List<Tag> tags;
  final DateTime createDate;
  final int pageCount;
  final int width;
  final int height;
  final int totalView;
  final int totalBookmarks;
  bool isBookmarked;
  final bool isAi;
  final bool isUgoira;
  final bool isBlocked;

  bool get isR18 => tags.contains(const Tag("R-18", null));

  bool get isR18G => tags.contains(const Tag("R-18G", null));

  Illust.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        type = json['type'],
        images = (() {
          List<IllustImage> images = [];
          for (var i in json['meta_pages']) {
            images.add(IllustImage(
                i['image_urls']['square_medium'],
                i['image_urls']['medium'],
                i['image_urls']['large'],
                i['image_urls']['original']));
          }
          if (images.isEmpty) {
            images.add(IllustImage(
                json['image_urls']['square_medium'],
                json['image_urls']['medium'],
                json['image_urls']['large'],
                json['meta_single_page']['original_image_url']));
          }
          return images;
        }()),
        caption = json['caption'],
        restrict = json['restrict'],
        author = Author(
            json['user']['id'],
            json['user']['name'],
            json['user']['account'],
            json['user']['profile_image_urls']['medium'],
            json['user']['is_followed'] ?? false),
        tags = (json['tags'] as List)
            .map((e) => Tag(e['name'], e['translated_name']))
            .toList(),
        createDate = DateTime.parse(json['create_date']),
        pageCount = json['page_count'],
        width = json['width'],
        height = json['height'],
        totalView = json['total_view'],
        totalBookmarks = json['total_bookmarks'],
        isBookmarked = json['is_bookmarked'],
        isAi = json['illust_ai_type'] == 2,
        isUgoira = json['type'] == "ugoira",
        isBlocked = json['is_muted'] ?? false;
}

class TrendingTag {
  final Tag tag;
  final Illust illust;

  TrendingTag(this.tag, this.illust);
}

enum KeywordMatchType {
  tagsPartialMatches("Tags partial match"),
  tagsExactMatch("Tags exact match"),
  mainText("Main Text"),
  keyword("Labels, titles, and descriptions");

  final String text;

  const KeywordMatchType(this.text);

  @override
  toString() => text;

  String toParam([String? searchType]) {
    if (searchType != "novel" && this == KeywordMatchType.mainText) {
      return "keyword"; // mainText search for illustration is not supported
    }

    return switch (this) {
      KeywordMatchType.tagsPartialMatches => "partial_match_for_tags",
      KeywordMatchType.tagsExactMatch => "exact_match_for_tags",
      KeywordMatchType.mainText => "text",
      KeywordMatchType.keyword => "keyword",
    };
  }
}

enum FavoriteNumber {
  unlimited(-1),
  f500(500),
  f1000(1000),
  f2000(2000),
  f5000(5000),
  f7500(7500),
  f10000(10000),
  f20000(20000),
  f50000(50000),
  f100000(100000);

  final int number;
  const FavoriteNumber(this.number);

  @override
  toString() =>
      this == FavoriteNumber.unlimited ? "Unlimited" : "$number Bookmarks";

  String toParam() =>
      this == FavoriteNumber.unlimited ? "" : " ${number}users入り";
}

enum SearchSort {
  newToOld,
  oldToNew,
  popular,
  popularMale,
  popularFemale;

  bool get isPremium => appdata.account?.user.isPremium == true;

  static List<SearchSort> get availableValues => [
        SearchSort.newToOld,
        SearchSort.oldToNew,
        SearchSort.popular,
        if (appdata.account?.user.isPremium == true) SearchSort.popularMale,
        if (appdata.account?.user.isPremium == true) SearchSort.popularFemale
      ];

  @override
  toString() {
    if (this == SearchSort.popular) {
      return isPremium ? "Popular" : "Popular(limited)";
    } else if (this == SearchSort.newToOld) {
      return "New to old";
    } else if (this == SearchSort.oldToNew) {
      return "Old to new";
    } else if (this == SearchSort.popularMale) {
      return "Popular(Male)";
    } else {
      return "Popular(Female)";
    }
  }

  String toParam() => switch (this) {
        SearchSort.newToOld => "date_desc",
        SearchSort.oldToNew => "date_asc",
        SearchSort.popular => "popular_desc",
        SearchSort.popularMale => "popular_male_desc",
        SearchSort.popularFemale => "popular_female_desc",
      };
}

enum AgeLimit {
  unlimited("Unlimited"),
  allAges("All ages"),
  r18("R18");

  final String text;

  const AgeLimit(this.text);

  @override
  toString() => text;

  String toParam() => switch (this) {
        AgeLimit.unlimited => "",
        AgeLimit.allAges => " -R-18",
        AgeLimit.r18 => "R-18",
      };
}

class SearchOptions {
  KeywordMatchType matchType = KeywordMatchType.tagsPartialMatches;
  FavoriteNumber favoriteNumber = FavoriteNumber.unlimited;
  SearchSort sort = SearchSort.newToOld;
  DateTime? startTime;
  DateTime? endTime;
  AgeLimit ageLimit = AgeLimit.unlimited;
}

/*
json:
{
        "id": 20542044,
        "name": "vocaloidhm01",
        "account": "vocaloidhm01",
        "profile_image_urls": {
          "medium": "https://i.pximg.net/user-profile/img/2023/04/28/00/21/54/24348957_c74a61e78ddccb467417be7c37b5d463_170.jpg"
        },
        "is_followed": false,
        "is_access_blocking_user": false
}
 */
class UserPreview {
  final int id;
  final String name;
  final String account;
  final String avatar;
  bool isFollowed;
  final bool isBlocking;
  final List<Illust> artworks;

  UserPreview(this.id, this.name, this.account, this.avatar, this.isFollowed,
      this.isBlocking, this.artworks);

  UserPreview.fromJson(Map<String, dynamic> json)
      : id = json['user']['id'],
        name = json['user']['name'],
        account = json['user']['account'],
        avatar = json['user']['profile_image_urls']['medium'],
        isFollowed = json['user']['is_followed'],
        isBlocking = json['user']['is_access_blocking_user'] ?? false,
        artworks =
            (json['illusts'] as List).map((e) => Illust.fromJson(e)).toList();
}

/*
{
      "id": 176418447,
      "comment": "",
      "date": "2024-05-13T19:28:13+09:00",
      "user": {
        "id": 54898889,
        "name": "Rorigod",
        "account": "user_gjzr2787",
        "profile_image_urls": {
          "medium": "https://i.pximg.net/user-profile/img/2021/09/01/00/46/58/21334581_94fac3456245d2b680ecf1c60aba2c95_170.png"
        }
      },
      "has_replies": false,
      "stamp": {
        "stamp_id": 407,
        "stamp_url": "https://s.pximg.net/common/images/stamp/generated-stamps/407_s.jpg?20180605"
      }
    }
 */
class Comment {
  final String id;
  final String comment;
  final DateTime date;
  final String uid;
  final String name;
  final String avatar;
  final bool hasReplies;
  final String? stampUrl;

  Comment.fromJson(Map<String, dynamic> json)
      : id = json['id'].toString(),
        comment = json['comment'],
        date = DateTime.parse(json['date']),
        uid = json['user']['id'].toString(),
        name = json['user']['name'],
        avatar = json['user']['profile_image_urls']['medium'],
        hasReplies = json['has_replies'] ?? false,
        stampUrl = json['stamp']?['stamp_url'];
}

/*
{
      "id": 20741342,
      "title": "中身が一般人のやつがれくん",
      "caption": "なんか思いついたので書いてみた。<br />よくある芥川成り代わり。<br />３年くらい前の書きかけのやつをサルベージ。<br />じっくりは書いてないので抜け抜け。<br /><br />デイリー１位ありがとうございます✨<br /><br />※※※※※※※※<br />※※※※※※※※<br /><br />以下読了後推奨の蛇足<br /><br />「芥川くん」<br />「なんですかボス」<br />「君は将来的にどんな地位につきたいとかある？」<br />「僕はしがない一構成員ゆえ」<br />「ほら幹部とか隊長とか人事部とかさ。君あれこれオールマイティにできるから希望を聞いておこうと思って」<br />「ございます」<br />「なにかな？」<br />「僕は将来的にポートマフィア直営のいちじく農家になりたいと思います」<br />「なんて？」<br />「さらに、ゆくゆくはいちじく農家兼、いちじくの素晴らしさを世に知らしめるポートマフィア直営いちじくレストランを開きたいと」<br />「なんて？？？」",
      "restrict": 0,
      "x_restrict": 0,
      "is_original": false,
      "image_urls": {
        "square_medium": "https://i.pximg.net/c/128x128/novel-cover-master/img/2023/09/27/16/14/45/ci20741342_db401e9b27afbf96f772d30759e1d104_square1200.jpg",
        "medium": "https://i.pximg.net/c/176x352/novel-cover-master/img/2023/09/27/16/14/45/ci20741342_db401e9b27afbf96f772d30759e1d104_master1200.jpg",
        "large": "https://i.pximg.net/c/240x480_80/novel-cover-master/img/2023/09/27/16/14/45/ci20741342_db401e9b27afbf96f772d30759e1d104_master1200.jpg"
      },
      "create_date": "2023-09-27T16:14:45+09:00",
      "tags": [
        {
          "name": "文スト夢",
          "translated_name": "Bungo Stray Dogs original/self-insert",
          "added_by_uploaded_user": true
        },
        {
          "name": "成り代わり",
          "translated_name": "取代即有角色",
          "added_by_uploaded_user": true
        },
      ],
      "page_count": 6,
      "text_length": 12550,
      "user": {
        "id": 9275134,
        "name": "もろろ",
        "account": "sleepinglife",
        "profile_image_urls": {
          "medium": "https://s.pximg.net/common/images/no_profile.png"
        },
        "is_followed": false
      },
      "series": {
        "id": 11897059,
        "title": "文スト夢"
      },
      "is_bookmarked": false,
      "total_bookmarks": 8099,
      "total_view": 76112,
      "visible": true,
      "total_comments": 146,
      "is_muted": false,
      "is_mypixiv_only": false,
      "is_x_restricted": false,
      "novel_ai_type": 1
    }
*/
class Novel {
  final int id;
  final String title;
  final String caption;
  final bool isOriginal;
  final String image;
  final DateTime createDate;
  final List<Tag> tags;
  final int pages;
  final int length;
  final Author author;
  final int? seriesId;
  final String? seriesTitle;
  bool isBookmarked;
  final int totalBookmarks;
  final int totalViews;
  final int commentsCount;
  final bool isAi;

  Novel.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        caption = json["caption"],
        isOriginal = json["is_original"],
        image = json["image_urls"]["large"] ??
            json["image_urls"]["medium"] ??
            json["image_urls"]["square_medium"] ??
            "",
        createDate = DateTime.parse(json["create_date"]),
        tags = (json['tags'] as List)
            .map((e) => Tag(e['name'], e['translated_name']))
            .toList(),
        pages = json["page_count"],
        length = json["text_length"],
        author = Author(
            json['user']['id'],
            json['user']['name'],
            json['user']['account'],
            json['user']['profile_image_urls']['medium'],
            json['user']['is_followed'] ?? false),
        seriesId = json["series"]?["id"],
        seriesTitle = json["series"]?["title"],
        isBookmarked = json["is_bookmarked"],
        totalBookmarks = json["total_bookmarks"],
        totalViews = json["total_view"],
        commentsCount = json["total_comments"],
        isAi = json["novel_ai_type"] == 2;
}

class MuteList {
  List<Tag> tags;

  List<Author> authors;

  int limit;

  MuteList(this.tags, this.authors, this.limit);

  static MuteList? fromJson(Map<String, dynamic> data) {
    return MuteList(
        (data['muted_tags'] as List)
            .map((e) => Tag(e['tag'], e['tag_translation']))
            .toList(),
        (data['muted_users'] as List)
            .map((e) => Author(e['user_id'], e['user_name'], e['user_account'],
                e['user_profile_image_urls']['medium'], false))
            .toList(),
        data['mute_limit_count']);
  }
}
