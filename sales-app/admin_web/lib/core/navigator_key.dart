import 'package:flutter/material.dart';

/// Root Navigator key dipakai untuk redirect ke LoginScreen dari callback
/// yang dipanggil di luar widget tree (mis. handler 401 dari Dio interceptor
/// di admin_web, atau onTokenExpired di mobile).
///
/// WAJIB di-pass ke MaterialApp.navigatorKey supaya key ini ter-attach.
/// Kalau tidak, GlobalKey.currentState akan null dan redirect tidak terjadi.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
