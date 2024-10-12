import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/payment_confirmation_bloc.dart';
import '../bloc/payment_confirmation_event.dart';
import '../bloc/payment_confirmation_state.dart';
import '../../widgets/bottom_nav_bar.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  const PaymentConfirmationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentConfirmationBloc()..add(LoadPaymentConfirmation()),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('PAYMENT', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<PaymentConfirmationBloc, PaymentConfirmationState>(
          builder: (context, state) {
            if (state is PaymentConfirmationLoading) {
              return Center(child: CircularProgressIndicator());
            } else if (state is PaymentConfirmationLoaded) {
              return Center(
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFF303544),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF8CC541),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        '${state.satoshisReceived} satoshis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'received',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        child: Text('CONTINUE'),
                        style: ElevatedButton.styleFrom(
                          primary: Color(0xFF8CC541),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          context.read<PaymentConfirmationBloc>().add(ContinueAfterConfirmation());
                          // Aquí puedes navegar a la siguiente pantalla o realizar la acción necesaria
                        },
                      ),
                    ],
                  ),
                ),
              );
            } else if (state is PaymentConfirmationError) {
              return Center(
                child: Text(
                  'Error: ${state.error}',
                  style: TextStyle(color: Colors.white),
                ),
              );
            } else {
              return Center(
                child: Text(
                  'Unexpected state',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
          },
        ),
        bottomNavigationBar: BottomNavBar(),
      ),
    );
  }
}