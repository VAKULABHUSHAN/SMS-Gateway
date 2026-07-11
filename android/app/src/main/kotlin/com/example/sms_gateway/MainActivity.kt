package com.example.sms_gateway

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "sms_gateway"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "sendSms") {

                val number = call.argument<String>("number")
                val message = call.argument<String>("message")

                if (number == null || message == null) {
                    result.error("INVALID", "Missing data", null)
                    return@setMethodCallHandler
                }

                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {

                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.SEND_SMS),
                        100
                    )

                    result.error(
                        "PERMISSION",
                        "SMS permission not granted",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val smsManager =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            applicationContext.getSystemService(SmsManager::class.java)
                        } else {
                            SmsManager.getDefault()
                        }

                    smsManager.sendTextMessage(
                        number,
                        null,
                        message,
                        null,
                        null
                    )

                    result.success("SMS Sent")

                } catch (e: Exception) {

                    result.error(
                        "FAILED",
                        e.message,
                        null
                    )

                }

            } else {

                result.notImplemented()

            }

        }
    }
}