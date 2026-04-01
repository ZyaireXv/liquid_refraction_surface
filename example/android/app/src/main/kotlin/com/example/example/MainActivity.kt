package com.example.example

import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val backendChannelName = "liquid_refraction_surface/debug_backend"
        private const val impellerBackendMetaDataKey =
            "io.flutter.embedding.android.ImpellerBackend"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backendChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRequestedBackend" -> result.success(resolveRequestedBackend())
                else -> result.notImplemented()
            }
        }
    }

    private fun resolveRequestedBackend(): String {
        return try {
            // 这里读取的是当前安装包真正生效的 AndroidManifest 元数据，
            // 不是 Dart 侧自己拼出来的一份调试字符串。
            //
            // 这样做的目的很直接：
            // 后端切换本身发生在 Android 启动参数阶段，
            // 角标如果不从原生侧取值，就很容易出现“界面显示 Vulkan，
            // 实际构建却还是 Auto”这种排查时最容易误判的问题。
            val applicationInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            applicationInfo.metaData
                ?.getString(impellerBackendMetaDataKey)
                ?.trim()
                ?.lowercase()
                ?.takeIf { it.isNotEmpty() }
                ?: "auto"
        } catch (_: Exception) {
            // 这里统一回落到 auto，而不是把读取异常直接抛到 Dart 侧，
            // 是因为这个角标只承担“帮助确认当前测试目标”的职责。
            // 真正的图形后端仍然由 Flutter engine 决定，调试提示不该反过来影响页面启动。
            "auto"
        }
    }
}
