part of '../main.dart';

backend.AppRole backendRoleFor(DemoRole role) {
  switch (role) {
    case DemoRole.customer:
      return backend.AppRole.customer;
    case DemoRole.driver:
      return backend.AppRole.worker;
    case DemoRole.storeOwner:
      return backend.AppRole.storeOwner;
    case DemoRole.admin:
      // TODO: Production owner roles should be controlled by Firestore roles/custom claims.
      return backend.AppRole.owner;
  }
}

DemoRole demoRoleForBackend(backend.AppRole role) {
  switch (role) {
    case backend.AppRole.customer:
      return DemoRole.customer;
    case backend.AppRole.worker:
      return DemoRole.driver;
    case backend.AppRole.storeOwner:
      return DemoRole.storeOwner;
    case backend.AppRole.owner:
      return DemoRole.admin;
  }
}
