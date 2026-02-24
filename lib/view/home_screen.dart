import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tirocinio_template/view/query_screen.dart';
import 'package:tirocinio_template/view/rt_screen.dart';
import 'package:tirocinio_template/view/edit_screen.dart';
import 'package:tirocinio_template/viewmodel/edit_viewmodel.dart';
import '../model/machineinfo.dart';
import '../viewmodel/rt_viewmodel.dart';

class HomeScreen extends StatefulWidget {
  final List<MachineInfo> machines;
  final String accessToken;

  const HomeScreen({super.key, required this.machines, required this.accessToken});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final List<RTViewModel> _viewModels;
  late final PageController _pageController;
  late final ValueNotifier<bool> hasDataNotifier;

  bool _swipeParameter = true;
  bool _groupByLocation = false;
  bool _globalStreaming = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    hasDataNotifier = ValueNotifier(false);

    RTViewModel.streamingEnabled = true;

    _viewModels = widget.machines.map((info) {
      final vm = RTViewModel(info.topic, info.location, info.smartObject, info.sourceId, info.fields, widget.accessToken);
      vm.onFirstData = () {
        if (!hasDataNotifier.value) {
          hasDataNotifier.value = true;
        }
      };
      return vm;
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    hasDataNotifier.dispose();
    for (var vm in _viewModels) {
      vm.dispose();
    }
    super.dispose();
  }

  Widget _singleList() {
    return ListView(
      children: _viewModels.map((vm) => ChangeNotifierProvider.value(
        value: vm,
        child: const RealTimeData(),
      )).toList(),
    );
  }

  Widget _groupedList() {
    final groups = <String, List<RTViewModel>>{};
    for (var vm in _viewModels) {
      groups.putIfAbsent(vm.location, () => []).add(vm);
    }

    return ListView(
      children: groups.entries.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Location: ${entry.key}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ...entry.value.map((vm) => ChangeNotifierProvider.value(
            value: vm,
            child: const RealTimeData(),
          )),
        ];
      }).toList(),
    );
  }

  void _openEditScreen() {
    final machineParamsMap = {
      for (var vm in _viewModels)
        if (vm.machineList.isNotEmpty)
          vm.sensorId: vm.getAllAvailableKeys().where((k) => k != 'machine_id').toList()
    };

    if (machineParamsMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data found")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => EditViewModel(machineParamsMap),
          child: const EditScreen(),
        ),
      ),
    );
  }

  void _toggleGlobalStreaming(bool value) {
    setState(() {
      _globalStreaming = value;
      RTViewModel.streamingEnabled = value;
    });

    for (var vm in _viewModels) {
      if (value) {
        if (!vm.streamActive) {
          vm.startStream();
        }
      } else {
        vm.stopStream();
      }
      vm.refreshUI();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SizedBox(width: 8),
            Text(
              _swipeParameter ? 'Real Time Data' : 'Query Data',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        leading: ValueListenableBuilder<bool>(
          valueListenable: hasDataNotifier,
          builder: (context, hasData, _) {
            return IconButton(
              icon: const Icon(Icons.edit),
              onPressed: hasData ? _openEditScreen : null,
              tooltip: 'Modify',
              color: hasData ? Colors.white : Colors.grey,
            );
          },
        ),
        actions: [
          if (_swipeParameter) ...[
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () {
                setState(() {
                  _groupByLocation = !_groupByLocation;
                });
              },
              tooltip: 'Order by location',
            ),
            Row(
              children: [
                const Text("Streaming", style: TextStyle(fontSize: 14)),
                Switch(
                  value: _globalStreaming,
                  onChanged: _toggleGlobalStreaming,
                ),
              ],
            ),
          ],
        ],
      ),
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        onPageChanged: (index) {
          setState(() {
            _swipeParameter = index == 0;
          });
        },
        children: [
          _groupByLocation ? _groupedList() : _singleList(),
          QueryData(
            machines: widget.machines,
            accessToken: widget.accessToken,
          ),
        ],
      ),
    );
  }
}
