import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';

class CreateTripArgs {
  final AnnouncementModel? announcement;
  final LockedTripContext? lockContext;
  final NegotiationBloc? negotiationBloc;
  final bool lockCorridorAndDate;

  const CreateTripArgs({
    this.announcement,
    this.lockContext,
    this.negotiationBloc,
    this.lockCorridorAndDate = false,
  });
}

class CreateTripScreen extends StatefulWidget {
  final CreateTripArgs? args;

  const CreateTripScreen({super.key, this.args});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  @override
  void initState() {
    super.initState();
    final args = widget.args;
    final isCreation = args?.announcement == null && args?.lockContext == null;
    if (isCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            getIt<AnalyticsService>().logEvent(AnalyticsEvents.tripCreateStarted),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final isLocked = args?.lockContext != null;
    final isEdit   = args?.announcement != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          isLocked ? 'Créer le trajet pour cette demande'
              : (isEdit ? 'Modifier le trajet' : 'Publier un trajet'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
