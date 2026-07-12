import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:pixes/foundation/app.dart';
import 'package:pixes/network/res.dart';

Widget buildRefreshWrapper({
  required Widget child,
  required Future<void> Function() onRefresh,
}) {
  return material.RefreshIndicator(
    onRefresh: onRefresh,
    child: child,
  );
}

abstract class LoadingState<T extends StatefulWidget, S extends Object> extends State<T>{
  bool isLoading = false;

  S? data;

  String? error;

  Future<Res<S>> loadData();

  Widget buildContent(BuildContext context, S data);

  Widget? buildFrame(BuildContext context, Widget child) => null;

  Widget buildLoading() {
    return const Center(
      child: ProgressRing(),
    );
  }

  Future<void> retry() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    final value = await loadData();
    if (!mounted) return;
    if(value.success) {
      setState(() {
        isLoading = false;
        data = value.data;
      });
    } else {
      setState(() {
        isLoading = false;
        error = value.errorMessage!;
      });
    }
  }

  Future<void> refresh() {
    return retry();
  }

  Widget withRefresh(Widget child) {
    return buildRefreshWrapper(
      onRefresh: refresh,
      child: child,
    );
  }

  void _loadInitialData() {
    loadData().then((value) {
      if (!mounted) return;
      if(value.success) {
        setState(() {
          isLoading = false;
          data = value.data;
        });
      } else {
        setState(() {
          isLoading = false;
          error = value.errorMessage!;
        });
      }
    });
  }

  Widget buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error!),
          const SizedBox(height: 12),
          Button(
            onPressed: retry,
            child: const Text("Retry"),
          )
        ],
      ),
    ).paddingHorizontal(16);
  }

  @override
  @mustCallSuper
  void initState() {
    isLoading = true;
    _loadInitialData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if(isLoading){
      child = buildLoading();
    } else if (error != null){
      child = buildError();
    } else {
      child = buildContent(context, data!);
    }

    return buildFrame(context, child) ?? child;
  }
}

abstract class MultiPageLoadingState<T extends StatefulWidget, S extends Object> extends State<T>{
  bool _isFirstLoading = true;

  bool _isLoading = false;

  List<S>? _data;

  String? _error;

  int _page = 1;

  Completer<void>? _refreshCompleter;

  Future<Res<List<S>>> loadData(int page);

  Widget? buildFrame(BuildContext context, Widget child) => null;

  Widget buildContent(BuildContext context, List<S> data);

  bool get isLoading => _isLoading || _isFirstLoading;

  bool get isFirstLoading => _isFirstLoading;

  void nextPage() {
    if(_isLoading) return;
    _isLoading = true;
    loadData(_page).then((value) {
      _isLoading = false;
      if(value.success) {
        _page++;
        setState(() {
          _data!.addAll(value.data);
        });
      } else {
        var message = value.errorMessage ?? "Network Error";
        if(message == "No more data") {
          return;
        }
        if(message.length > 20) {
          message = "${message.substring(0, 20)}...";
        }
        if (mounted) {
          context.showToast(message: message);
        }
      }
    });
  }

  void reset() {
    setState(() {
      _isFirstLoading = true;
      _isLoading = false;
      _data = null;
      _error = null;
      _page = 1;
    });
    firstLoad();
  }

  Future<void> refresh() {
    final completer = Completer<void>();
    _refreshCompleter = completer;
    reset();
    return completer.future;
  }

  Widget withRefresh(Widget child) {
    return buildRefreshWrapper(
      onRefresh: refresh,
      child: child,
    );
  }

  void firstLoad() {
    loadData(_page).then((value) {
      if (!mounted) return;
      if(value.success) {
        _page++;
        setState(() {
          _isFirstLoading = false;
          _data = value.data;
        });
      } else {
        setState(() {
          _isFirstLoading = false;
          _error = value.errorMessage!;
        });
      }
      _refreshCompleter?.complete();
      _refreshCompleter = null;
    });
  }

  @override
  void initState() {
    firstLoad();
    super.initState();
  }

  Widget buildLoading(BuildContext context) {
    return const Center(
      child: ProgressRing(),
    );
  }

  Widget buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error),
          const SizedBox(height: 12),
          Button(
            onPressed: () {
              reset();
            },
            child: const Text("Retry"),
          )
        ],
      ),
    ).paddingHorizontal(16);
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if(_isFirstLoading){
      child = buildLoading(context);
    } else if (_error != null){
      child = buildError(context, _error!);
    } else {
      child = buildContent(context, _data!);
    }

    return buildFrame(context, child) ?? child;
  }
}
