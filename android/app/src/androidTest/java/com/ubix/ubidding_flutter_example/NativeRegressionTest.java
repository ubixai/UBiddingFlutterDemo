package com.ubix.ubidding_flutter_example;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/** Runs the explicitly selected integration_test Dart target without a host VM driver. */
@RunWith(FlutterTestRunner.class)
public class NativeRegressionTest {
  @Rule
  public ActivityTestRule<MainActivity> activity =
      new ActivityTestRule<>(MainActivity.class, true, false);
}
