// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionProvidersHash() => r'7756994a4a75d695f0ea3377c0a3158155a46e50';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [sessionProviders].
@ProviderFor(sessionProviders)
const sessionProvidersProvider = SessionProvidersFamily();

/// See also [sessionProviders].
class SessionProvidersFamily extends Family<SessionProviders> {
  /// See also [sessionProviders].
  const SessionProvidersFamily();

  /// See also [sessionProviders].
  SessionProvidersProvider call(
    String orderId,
  ) {
    return SessionProvidersProvider(
      orderId,
    );
  }

  @override
  SessionProvidersProvider getProviderOverride(
    covariant SessionProvidersProvider provider,
  ) {
    return call(
      provider.orderId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionProvidersProvider';
}

/// See also [sessionProviders].
class SessionProvidersProvider extends AutoDisposeProvider<SessionProviders> {
  /// See also [sessionProviders].
  SessionProvidersProvider(
    String orderId,
  ) : this._internal(
          (ref) => sessionProviders(
            ref as SessionProvidersRef,
            orderId,
          ),
          from: sessionProvidersProvider,
          name: r'sessionProvidersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sessionProvidersHash,
          dependencies: SessionProvidersFamily._dependencies,
          allTransitiveDependencies:
              SessionProvidersFamily._allTransitiveDependencies,
          orderId: orderId,
        );

  SessionProvidersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.orderId,
  }) : super.internal();

  final String orderId;

  @override
  Override overrideWith(
    SessionProviders Function(SessionProvidersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SessionProvidersProvider._internal(
        (ref) => create(ref as SessionProvidersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        orderId: orderId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<SessionProviders> createElement() {
    return _SessionProvidersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionProvidersProvider && other.orderId == orderId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, orderId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionProvidersRef on AutoDisposeProviderRef<SessionProviders> {
  /// The parameter `orderId` of this provider.
  String get orderId;
}

class _SessionProvidersProviderElement
    extends AutoDisposeProviderElement<SessionProviders>
    with SessionProvidersRef {
  _SessionProvidersProviderElement(super.provider);

  @override
  String get orderId => (origin as SessionProvidersProvider).orderId;
}

String _$sessionMessagesHash() => r'a8f6f4e0f8ec58f745b1e1acd68651436706d948';

abstract class _$SessionMessages
    extends BuildlessAutoDisposeStreamNotifier<MostroMessage> {
  late final String orderId;

  Stream<MostroMessage> build(
    String orderId,
  );
}

/// See also [SessionMessages].
@ProviderFor(SessionMessages)
const sessionMessagesProvider = SessionMessagesFamily();

/// See also [SessionMessages].
class SessionMessagesFamily extends Family<AsyncValue<MostroMessage>> {
  /// See also [SessionMessages].
  const SessionMessagesFamily();

  /// See also [SessionMessages].
  SessionMessagesProvider call(
    String orderId,
  ) {
    return SessionMessagesProvider(
      orderId,
    );
  }

  @override
  SessionMessagesProvider getProviderOverride(
    covariant SessionMessagesProvider provider,
  ) {
    return call(
      provider.orderId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionMessagesProvider';
}

/// See also [SessionMessages].
class SessionMessagesProvider extends AutoDisposeStreamNotifierProviderImpl<
    SessionMessages, MostroMessage> {
  /// See also [SessionMessages].
  SessionMessagesProvider(
    String orderId,
  ) : this._internal(
          () => SessionMessages()..orderId = orderId,
          from: sessionMessagesProvider,
          name: r'sessionMessagesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sessionMessagesHash,
          dependencies: SessionMessagesFamily._dependencies,
          allTransitiveDependencies:
              SessionMessagesFamily._allTransitiveDependencies,
          orderId: orderId,
        );

  SessionMessagesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.orderId,
  }) : super.internal();

  final String orderId;

  @override
  Stream<MostroMessage> runNotifierBuild(
    covariant SessionMessages notifier,
  ) {
    return notifier.build(
      orderId,
    );
  }

  @override
  Override overrideWith(SessionMessages Function() create) {
    return ProviderOverride(
      origin: this,
      override: SessionMessagesProvider._internal(
        () => create()..orderId = orderId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        orderId: orderId,
      ),
    );
  }

  @override
  AutoDisposeStreamNotifierProviderElement<SessionMessages, MostroMessage>
      createElement() {
    return _SessionMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionMessagesProvider && other.orderId == orderId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, orderId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionMessagesRef
    on AutoDisposeStreamNotifierProviderRef<MostroMessage> {
  /// The parameter `orderId` of this provider.
  String get orderId;
}

class _SessionMessagesProviderElement
    extends AutoDisposeStreamNotifierProviderElement<SessionMessages,
        MostroMessage> with SessionMessagesRef {
  _SessionMessagesProviderElement(super.provider);

  @override
  String get orderId => (origin as SessionMessagesProvider).orderId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
