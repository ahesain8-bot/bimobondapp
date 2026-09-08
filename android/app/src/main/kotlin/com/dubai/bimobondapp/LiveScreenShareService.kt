package com.dubai.bimobondapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Android 14+ (targetSdk 34+) requires a running mediaProjection foreground
 * service before [android.media.projection.MediaProjectionManager.getMediaProjection].
 * LiveKit / flutter_webrtc call that from OrientationAwareScreenCapturer.startCapture.
 */
class LiveScreenShareService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        startInForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSharingForeground()
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        return START_STICKY
    }

    override fun onDestroy() {
        stopSharingForeground()
        super.onDestroy()
    }

    private fun stopSharingForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startInForeground() {
        val notification: Notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(getString(R.string.live_screen_share_notification_title))
                .setContentText(getString(R.string.live_screen_share_notification_text))
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setSilent(true)
                .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.live_screen_share_notification_channel),
                NotificationManager.IMPORTANCE_LOW,
            )
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "live_screen_share"
        const val NOTIFICATION_ID = 49021
        const val ACTION_STOP = "com.dubai.bimobondapp.STOP_LIVE_SCREEN_SHARE"

        fun start(context: Context) {
            val intent = Intent(context, LiveScreenShareService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent =
                Intent(context, LiveScreenShareService::class.java).setAction(ACTION_STOP)
            // stopService() never delivers ACTION_STOP to onStartCommand, so
            // stopForeground() would be skipped. startService() hits the
            // ACTION_STOP branch (stopForeground + stopSelf).
            try {
                context.startService(intent)
            } catch (_: Exception) {
                context.stopService(Intent(context, LiveScreenShareService::class.java))
            }
        }
    }
}
