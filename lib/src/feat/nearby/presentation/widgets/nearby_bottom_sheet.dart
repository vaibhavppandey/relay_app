import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:relay_app/src/feat/nearby/bloc/nearby_bloc.dart';

class NearbyBottomSheet extends StatefulWidget {
  const NearbyBottomSheet({required this.myCode, super.key});

  final String myCode;

  @override
  State<NearbyBottomSheet> createState() => _NearbyBottomSheetState();
}

class _NearbyBottomSheetState extends State<NearbyBottomSheet> {
  late final NearbyBloc _nearbyBloc;

  @override
  void initState() {
    super.initState();
    _nearbyBloc = context.read<NearbyBloc>();
    _nearbyBloc.add(const StartScanning());
  }

  @override
  void dispose() {
    _nearbyBloc.add(const StopScanning());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nearby Devices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            16.verticalSpace,
            Flexible(
              child: BlocBuilder<NearbyBloc, NearbyState>(
                builder: (context, state) {
                  if (state is NearbyFailure) {
                    return Center(child: Text(state.msg));
                  }

                  if (state is NearbySearching) {
                    return _buildSearching();
                  }

                  if (state is NearbyScanning) {
                    final myCode = widget.myCode.trim();
                    final lst = state.devices.where((srv) {
                      final name = (srv.name ?? '').trim();
                      if (myCode.isEmpty) {
                        return true;
                      }
                      if (name == myCode) {
                        return false;
                      }
                      if (name.startsWith('$myCode ')) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (lst.isEmpty) {
                      return const Center(
                        child: Text('No nearby devices found.'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: lst.length,
                      itemBuilder: (context, i) {
                        final srv = lst[i];
                        return ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(srv.name ?? 'Unknown'),
                          subtitle: Text('${srv.host ?? ''}:${srv.port ?? 0}'),
                          onTap: () {
                            Navigator.of(context).pop(srv);
                          },
                        );
                      },
                    );
                  }

                  return _buildSearching();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearching() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          16.verticalSpace,
          const Text('Searching for nearby devices...'),
        ],
      ),
    );
  }
}
