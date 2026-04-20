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
  String? _busy;
  NearbyBloc? _nearbyBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nearbyBloc != null) {
      return;
    }

    _nearbyBloc = context.read<NearbyBloc>();
    _nearbyBloc!.add(const StartScanning());
  }

  @override
  void dispose() {
    _nearbyBloc?.add(const StopScanning());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: BlocBuilder<NearbyBloc, NearbyState>(
          builder: (context, state) {
            if (state is NearbyFailure) {
              return Center(child: Text(state.msg));
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
                return const Center(child: Text('No nearby devices found.'));
              }

              return ListView.builder(
                itemCount: lst.length,
                itemBuilder: (context, i) {
                  final srv = lst[i];
                  final id =
                      '${srv.name ?? ''}-${srv.host ?? ''}-${srv.port ?? 0}';
                  final busy = _busy == id;
                  return ListTile(
                    title: Text(srv.name ?? 'Unknown'),
                    subtitle: Text('${srv.host ?? ''}:${srv.port ?? 0}'),
                    trailing: busy
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: CircularProgressIndicator(strokeWidth: 2.r),
                          )
                        : null,
                    onTap: busy
                        ? null
                        : () async {
                            setState(() {
                              _busy = id;
                            });
                            final code = srv.name;
                            if (code == null || code.isEmpty) {
                              setState(() {
                                _busy = null;
                              });
                              return;
                            }
                            Navigator.of(context).pop(code);
                          },
                  );
                },
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
