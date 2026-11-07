package com.mediabackup.scanner.scanner

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log

class MediaSyncJobService : JobService() {
    companion object {
        private const val TAG = "MediaSyncJobService"
        const val JOB_ID_MEDIA_CHANGE = 98124
        const val JOB_ID_PERIODIC_WAKE = 98125

        fun scheduleMediaChangeJob(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
            try {
                val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler ?: return
                val componentName = ComponentName(context, MediaSyncJobService::class.java)

                val builder = JobInfo.Builder(JOB_ID_MEDIA_CHANGE, componentName)
                    .addTriggerContentUri(
                        JobInfo.TriggerContentUri(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS
                        )
                    )
                    .addTriggerContentUri(
                        JobInfo.TriggerContentUri(
                            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                            JobInfo.TriggerContentUri.FLAG_NOTIFY_FOR_DESCENDANTS
                        )
                    )
                    .setTriggerContentUpdateDelay(500L) // Wait 500ms after write completes
                    .setTriggerContentMaxDelay(2000L) // Max 2s delay

                val result = jobScheduler.schedule(builder.build())
                if (result == JobScheduler.RESULT_SUCCESS) {
                    Log.d(TAG, "Successfully registered MediaStore ContentUriTrigger job with JobScheduler.")
                } else {
                    Log.w(TAG, "JobScheduler schedule failed with result code: $result")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule media change job: ${e.message}")
            }
        }

        fun schedulePeriodicWakeJob(context: Context) {
            try {
                val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler ?: return
                val componentName = ComponentName(context, MediaSyncJobService::class.java)

                // Minimum periodic interval supported by JobScheduler is 15 minutes (900000ms)
                val builder = JobInfo.Builder(JOB_ID_PERIODIC_WAKE, componentName)
                    .setPeriodic(15 * 60 * 1000L)
                    .setPersisted(true)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)

                val result = jobScheduler.schedule(builder.build())
                Log.d(TAG, "Scheduled periodic JobScheduler wake-up (result: $result)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule periodic job: ${e.message}")
            }
        }
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        val jobId = params?.jobId ?: 0
        Log.d(TAG, "Job started! Job ID: $jobId. Triggered by Android OS.")

        if (!MediaSyncWatchdog.hasMediaPermissions(this)) {
            Log.d(TAG, "Media permissions not yet granted. Finishing Job without running.")
            jobFinished(params, false)
            return false
        }

        // 1. Re-arm media trigger immediately for continuous detection
        if (jobId == JOB_ID_MEDIA_CHANGE) {
            scheduleMediaChangeJob(this)
        }

        // 2. Keep CPU awake while sync initializes
        MediaSyncWatchdog.startContinuousKeepAlive(this)
        MediaSyncWatchdog.acquireWakeLock(this, 120000L)

        // 3. Immediately trigger backup sync in BackgroundService
        MediaSyncWatchdog.triggerSyncNow(this)

        // 4. Also re-arm silent hardware alarm
        MediaSyncWatchdog.scheduleSilentAlarm(this)

        // Asynchronous background task; finish job after giving sync time to launch
        Thread {
            try {
                Thread.sleep(15000L)
            } catch (_: Exception) {}
            jobFinished(params, false)
        }.start()

        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        Log.d(TAG, "Job stopped early by system. Rescheduling...")
        return true
    }
}

