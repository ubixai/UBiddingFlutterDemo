import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

enum NativeVideoCommand {
  mute('静音'),
  unmute('取消静音'),
  start('开始'),
  pause('暂停'),
  resume('恢复'),
  stop('停止');

  const NativeVideoCommand(this.label);
  final String label;
}

/// Example-only controls; the caller owns the SDK object and command lifecycle.
class NativeVideoControls extends StatelessWidget {
  const NativeVideoControls({
    super.key,
    required this.enabled,
    required this.onCommand,
    this.commandStatus = '',
  });

  final bool enabled;
  final ValueChanged<NativeVideoCommand> onCommand;
  final String commandStatus;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final command in NativeVideoCommand.values)
            TextButton(
              key: ValueKey('native-video-${command.name}'),
              onPressed: enabled ? () => onCommand(command) : null,
              child: Text(command.label),
            ),
        ],
      ),
      if (commandStatus.isNotEmpty) Text(commandStatus),
    ],
  );
}

@Preview(name: '自渲染视频控制', size: Size(320, 220))
Widget nativeVideoControlsPreview() => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: NativeVideoControls(
        enabled: true,
        onCommand: (_) {},
        commandStatus: '命令返回仅代表 ACK，播放状态以 SDK 事件为准',
      ),
    ),
  ),
);
