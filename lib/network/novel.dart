part of "network.dart";

extension NovelExt on Network {
  Future<Res<List<Novel>>> getRecommendNovels() {
    return getNovelsWithNextUrl("/v1/novel/recommended");
  }

  Future<Res<List<Novel>>> getNovelsWithNextUrl(String nextUrl) async {
    var res = await apiGet(nextUrl);
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return Res(
        (res.data["novels"] as List).map((e) => Novel.fromJson(e)).toList(),
        subData: res.data["next_url"]);
  }

  Future<Res<List<Novel>>> searchNovels(String keyword, SearchOptions options) {
    final aiType = options.includeAiGeneratedWorks ? 1 : 0;
    var url = "/v1/search/novel?"
        "include_translated_tag_results=true&"
        "merge_plain_keyword_results=true&"
        "word=${Uri.encodeComponent(keyword)}&"
        "sort=${options.sort.toParam()}&"
        "search_target=${options.matchType.toParam()}&"
        "search_ai_type=$aiType";
    return getNovelsWithNextUrl(url);
  }

  /// mode: day, day_male, day_female, week_rookie, week, week_ai
  Future<Res<List<Novel>>> getNovelRanking(String mode, DateTime? date) {
    var url = "/v1/novel/ranking?mode=$mode";
    if (date != null) {
      url += "&date=${date.year}-${date.month}-${date.day}";
    }
    return getNovelsWithNextUrl(url);
  }

  Future<Res<List<Novel>>> getBookmarkedNovels(String uid, bool public) {
    return getNovelsWithNextUrl(
        "/v1/user/bookmarks/novel?user_id=$uid&restrict=${public ? "public" : "private"}");
  }

  Future<Res<bool>> favoriteNovel(String id, bool public) async {
    var res = await apiPost("/v2/novel/bookmark/add", data: {
      "novel_id": id,
      "restrict": public ? "public" : "private",
    });
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return const Res(true);
  }

  Future<Res<bool>> deleteFavoriteNovel(String id) async {
    var res = await apiPost("/v1/novel/bookmark/delete", data: {
      "novel_id": id,
    });
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return const Res(true);
  }

  Future<Res<String>> getNovelContent(String id) async {
    var res = await apiGetPlain(
        "/webview/v2/novel?id=$id&font=default&font_size=16.0px&line_height=1.75&color=%23101010&background_color=%23EFEFEF&margin_top=56px&margin_bottom=48px&theme=light&use_block=true&viewer_version=20221031_ai");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    try {
      var html = res.data;
      int start = html.indexOf("novel:");
      while (html[start] != '{') {
        start++;
      }
      int leftCount = 0;
      int end = start;
      for (end = start; end < html.length; end++) {
        if (html[end] == '{') {
          leftCount++;
        } else if (html[end] == '}') {
          leftCount--;
        }
        if (leftCount == 0) {
          end++;
          break;
        }
      }
      var json = jsonDecode(html.substring(start, end));
      return Res(json['text']);
    } catch (e, s) {
      Log.error(
          "Data Convert", "Failed to analyze html novel content: \n$e\n$s");
      return Res.error(e);
    }
  }

  Future<Res<List<Novel>>> relatedNovels(String id) async {
    var res = await apiPost("/v1/novel/related", data: {
      "novel_id": id,
    });
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return Res(
        (res.data["novels"] as List).map((e) => Novel.fromJson(e)).toList());
  }

  Future<Res<List<Novel>>> getUserNovels(String uid) {
    return getNovelsWithNextUrl("/v1/user/novels?user_id=$uid");
  }

  Future<Res<List<Novel>>> getNovelSeries(String id, [String? nextUrl]) async {
    var res = await apiGet(nextUrl ?? "/v2/novel/series?series_id=$id");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return Res(
        (res.data["novels"] as List).map((e) => Novel.fromJson(e)).toList(),
        subData: res.data["next_url"]);
  }

  Future<Res<List<Comment>>> getNovelComments(String id,
      [String? nextUrl]) async {
    var res = await apiGet(nextUrl ?? "/v1/novel/comments?novel_id=$id");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return Res(
        (res.data["comments"] as List).map((e) => Comment.fromJson(e)).toList(),
        subData: res.data["next_url"]);
  }

  Future<Res<bool>> commentNovel(String id, String content) async {
    var res = await apiPost("/v1/novel/comment/add", data: {
      "novel_id": id,
      "content": content,
    });
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return const Res(true);
  }

  Future<Res<Novel>> getNovelDetail(String id) async {
    var res = await apiGet("/v2/novel/detail?novel_id=$id");
    if (res.error) {
      return Res.fromErrorRes(res);
    }
    return Res(Novel.fromJson(res.data["novel"]));
  }

  Future<Res<List<Novel>>> getFollowingNovels(String restrict,
      [String? nextUrl]) async {
    var res = await apiGet(nextUrl ?? "/v1/novel/follow?restrict=$restrict");
    if (res.success) {
      return Res(
        (res.data["novels"] as List).map((e) => Novel.fromJson(e)).toList(),
        subData: res.data["next_url"],
      );
    } else {
      return Res.error(res.errorMessage);
    }
  }
}
