
package com.lixl.waveform;

import android.app.Activity;
import android.app.Dialog;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.media.MediaRecorder;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.support.annotation.Nullable;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.support.v7.app.AppCompatActivity;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.lixl.waveform.view.VoiceLineView;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;

import static android.graphics.Color.argb;

import android.widget.Toast;

/**
 * Author: <a href="https://github.com/leeshare">lixl</a>
 * <p>
 * Created by lixl on 17/5/17.
 * <p>
 * show a waveform controlled by a voice
 * <p>
 */

public class WaveformViewModule extends ReactContextBaseJavaModule {

    private MediaRecorder mMediaRecorder;
    private boolean isAlive = true;
    private VoiceLineView voiceLineView;
    private Handler handler ;

    Activity activity;
    private Dialog dialog = null;

    private static final String BOX_HEIGHT = "boxHeight";

    public WaveformViewModule(ReactApplicationContext reactContext){
        super(reactContext);
    }

    @Override
    public String getName() {
        return "WaveformViewModule";
    }

    @ReactMethod
    public void alert(String message) {
        Toast.makeText(getReactApplicationContext(), message, Toast.LENGTH_LONG).show();
    }

    private void initMediaRecorder(){
        if (mMediaRecorder == null)
            mMediaRecorder = new MediaRecorder();

        mMediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mMediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.AMR_NB);
        mMediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT);
        File file = new File(Environment.getExternalStorageDirectory().getPath(), "hello.log");
        if (!file.exists()) {
            try {
                file.createNewFile();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        mMediaRecorder.setOutputFile(file.getAbsolutePath());
        mMediaRecorder.setMaxDuration(1000 * 60 * 10);
        try {
            mMediaRecorder.prepare();
        } catch (IOException e) {
            e.printStackTrace();
        }
        mMediaRecorder.start();


    }

    class MyClickListener implements View.OnClickListener {

        @Override
        public void onClick(View v) {
            hide();
        }
    }

    TextView btn;
    private void bindButtonClick(View view){
        btn = (TextView)view.findViewById(R.id.txtStopVoice);
        btn.setOnClickListener(new MyClickListener());
    }

    @ReactMethod
    public void init(ReadableMap options){
        activity = getCurrentActivity();
        if(activity != null){
            View view = activity.getLayoutInflater().inflate(R.layout.activity_main, null);
            //activity.setContentView(view);

            int height = 300;
            if(options.hasKey(BOX_HEIGHT)){
                height = options.getInt(BOX_HEIGHT);
            }
            if (dialog == null) {
                dialog = new Dialog(activity, R.style.Dialog_Full_Screen);
                dialog.setContentView(view);
                WindowManager.LayoutParams layoutParams = new WindowManager.LayoutParams();
                Window window = dialog.getWindow();
                if (window != null) {
                    layoutParams.flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
                    layoutParams.format = PixelFormat.TRANSPARENT;
                    layoutParams.windowAnimations = R.style.PickerAnim;
                    layoutParams.width = WindowManager.LayoutParams.MATCH_PARENT;
                    layoutParams.height = height;
                    layoutParams.gravity = Gravity.BOTTOM;
                    layoutParams.y = 0;
                    window.setAttributes(layoutParams);
                }

                dialog.show();
            } else {
                dialog.dismiss();
            }

            initMediaRecorder();

            bindButtonClick(view);
            //Thread thread = new Thread(this);

            Thread thread = new Thread(){
                public void run() {

                        Looper.prepare();

                        handler = new Handler() {
                            @Override
                            public void handleMessage(Message msg) {
                                super.handleMessage(msg);
                                if(mMediaRecorder==null) return;
                                double ratio = (double) mMediaRecorder.getMaxAmplitude() / 100;
                                double db = 0;// 分贝
                                //默认的最大音量是100,可以修改，但其实默认的，在测试过程中就有不错的表现
                                //你可以传自定义的数字进去，但需要在一定的范围内，比如0-200，就需要在xml文件中配置maxVolume
                                //同时，也可以配置灵敏度sensibility
                                if (ratio > 1)
                                    db = 20 * Math.log10(ratio);
                                //只要有一个线程，不断调用这个方法，就可以使波形变化
                                //主要，这个方法必须在ui线程中调用
                                voiceLineView.setVolume((int) (db));
                            }
                        };

                        try {
                            Thread.sleep(100);
                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        }
                    }

            };
            thread.start();

        }else {
            Toast.makeText(getReactApplicationContext(), "Activity is null", Toast.LENGTH_SHORT).show();
        }
    }

    @ReactMethod
    public void show() {
        if (dialog == null) {
            return;
        }
        if (!dialog.isShowing()) {
            initMediaRecorder();
            dialog.show();
        }
    }

    @ReactMethod
    public void hide() {
        if (dialog == null) {
            return;
        }
        if (dialog.isShowing()) {

            isAlive = false;
            mMediaRecorder.release();
            mMediaRecorder = null;

            dialog.dismiss();
        }
    }

    private static final String ERROR_NOT_INIT = "please initialize the component first";

    @ReactMethod
    public void isWaveformShow(Callback callback) {
        if (callback == null)
            return;
        if (dialog == null) {
            callback.invoke(ERROR_NOT_INIT);
        } else {
            callback.invoke(null, dialog.isShowing());
        }
    }

    /*private Handler handler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            super.handleMessage(msg);
            if(mMediaRecorder==null) return;
            double ratio = (double) mMediaRecorder.getMaxAmplitude() / 100;
            double db = 0;// 分贝
            //默认的最大音量是100,可以修改，但其实默认的，在测试过程中就有不错的表现
            //你可以传自定义的数字进去，但需要在一定的范围内，比如0-200，就需要在xml文件中配置maxVolume
            //同时，也可以配置灵敏度sensibility
            if (ratio > 1)
                db = 20 * Math.log10(ratio);
            //只要有一个线程，不断调用这个方法，就可以使波形变化
            //主要，这个方法必须在ui线程中调用
            voiceLineView.setVolume((int) (db));
        }
    };*/

    /*@Override
    protected void onDestroy() {
        isAlive = false;
        mMediaRecorder.release();
        mMediaRecorder = null;
        super.onDestroy();
    }*/

    //@Override
    public void onHostDestroy() {
        isAlive = false;
        mMediaRecorder.release();
        mMediaRecorder = null;
    }

}
