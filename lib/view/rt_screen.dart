import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/graph_builder.dart';
import '../viewmodel/rt_viewmodel.dart';

class RealTimeData extends StatefulWidget {
  const RealTimeData({super.key});

  @override
  State<RealTimeData> createState() => _RealTimeDataState();
}

class _RealTimeDataState extends State<RealTimeData> with AutomaticKeepAliveClientMixin {
  late RTViewModel vm;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      vm = context.read<RTViewModel>();
      if (RTViewModel.streamingEnabled) {
        vm.startStream();
      }
    });
  }

  @override
  bool get wantKeepAlive => false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    vm = context.read<RTViewModel>();
    if (RTViewModel.streamingEnabled && vm.machineList.isEmpty) {
      vm.startStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    vm = context.watch<RTViewModel>();
    final dataCount = vm.machineList.length;
    final nameSplit = vm.topic.split("_");
    final nameShowed = nameSplit.join(" ");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: dataCount >= 2
              ? () {
            vm.loadPreferences();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => ChangeNotifierProvider.value(
                value: vm,
                child: Consumer<RTViewModel>(
                  builder: (context, model, _) {
                    final widgets = <Widget>[];
                    final interval = model.maxAndMinValues;
                    final latest = model.machineList.last.key;

                    for (final key in latest.keys) {
                      if (key == 'machine_id' || key == 'timestamp') continue;
                      final isVisible = model.visibleChartMap[key] ?? false;
                      final color = model.chartColors[key] ?? Colors.grey;
                      final spec = model.specGetter[key];
                      if (isVisible) {
                        widgets.add(GraphBuilder.LinearChartRT(
                          context,
                          spec!,
                          color,
                          model.machineList,
                              (m) => (m[key] as num).toDouble(),
                          interval,
                        ));
                        widgets.add(const SizedBox(height: 80));
                      }
                    }

                    return DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.85,
                      maxChildSize: 0.95,
                      minChildSize: 0.4,
                      builder: (context, scrollController) =>
                          SingleChildScrollView(
                            controller: scrollController,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    model.topic,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...widgets,
                                ],
                              ),
                            ),
                          ),
                    );
                  },
                ),
              ),
            );
          }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nameShowed,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: RTViewModel.streamingEnabled && vm.streamActive,
                      onChanged: (value) {
                        if (value) {
                          if (RTViewModel.streamingEnabled) {
                            vm.startStream();
                          }
                        } else {
                          vm.stopStream();
                        }
                        setState(() {});
                      },
                    ),

                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(dataCount >= 2
                      ? "Tap to show graph"
                      : "Data needed $dataCount/2"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
