import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/presentation/profile/bloc/profile_bloc.dart';
import 'package:mostro_mobile/presentation/profile/bloc/profile_event.dart';
import 'package:mostro_mobile/presentation/profile/bloc/profile_state.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/presentation/widgets/custom_app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc()..add(LoadProfile()),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212C),
        appBar: const CustomAppBar(),
        body: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF303544),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Expanded(
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    print('Current profile state: ${state.status}');
                    switch (state.status) {
                      case ProfileStatus.initial:
                        return const Center(child: Text('Initializing...'));
                      case ProfileStatus.loading:
                        return const Center(child: CircularProgressIndicator());
                      case ProfileStatus.loaded:
                        return _buildProfileContent(state);
                      case ProfileStatus.error:
                        return Center(
                            child: Text('Error: ${state.errorMessage}'));
                    }
                  },
                ),
              ),
              const BottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(ProfileState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Text(
                state.username[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              state.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${state.rating}/5 (${state.completedTrades} trades)',
              style: const TextStyle(color: Color(0xFF8CC541)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Public Key',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D212C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.pubkey,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon:
                      const HeroIcon(HeroIcons.clipboard, color: Colors.white),
                  onPressed: () {
                    // TODO: Implementar copia al portapapeles
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
