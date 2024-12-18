#include "connection_status_observer.h"

#include <winsvc.h>

#include <iostream>
#include <thread>

#include "connection_status.h"
namespace wireguard_dart {

ConnectionStatusObserver::ConnectionStatusObserver() {}

ConnectionStatusObserver::~ConnectionStatusObserver() { Shutdown(); }

void ConnectionStatusObserver::StartObserving(std::wstring service_name) {
  if (m_running.load() == true) {
    return;
  }

  if (!service_name.empty()) {
    m_service_name = service_name;
  }

  if (m_service_name.empty()) {
    std::cerr << "Service name is empty" << std::endl;
    return;
  }

  SC_HANDLE service_manager = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);
  if (service_manager == NULL) {
    std::cerr << "Failed to open service manager: " << GetLastError() << std::endl;
    return;
  }
  SC_HANDLE service = OpenService(service_manager, &m_service_name[0], SERVICE_QUERY_STATUS | SERVICE_INTERROGATE);
  if (service == NULL) {
    std::cerr << "Failed to open service: " << GetLastError() << std::endl;
    CloseServiceHandle(service_manager);
    return;
  }

  m_running.store(true);
  m_watch_thread_stop.store(false);
  watch_thread = std::thread(&ConnectionStatusObserver::StartObservingThreadProc, this, service_manager, service);
}

void ConnectionStatusObserver::StopObserving() {
  m_watch_thread_stop.store(true);
  if (watch_thread.joinable()) {
    watch_thread.join();
  }
}

void ConnectionStatusObserver::Shutdown() {
  StopObserving();
  m_running.store(false);
}

void ConnectionStatusObserver::StartObservingThreadProc(SC_HANDLE service_manager, SC_HANDLE service) {
  SERVICE_NOTIFY s_notify = {0};
  s_notify.dwVersion = SERVICE_NOTIFY_STATUS_CHANGE;
  s_notify.pfnNotifyCallback = &ServiceNotifyCallback;
  s_notify.pContext = static_cast<void*>(this);
  while (!m_watch_thread_stop.load()) {
    if (NotifyServiceStatusChange(service,
                                  SERVICE_NOTIFY_RUNNING | SERVICE_NOTIFY_START_PENDING | SERVICE_NOTIFY_STOPPED |
                                      SERVICE_NOTIFY_STOP_PENDING,
                                  &s_notify) == ERROR_SUCCESS) {
      ::SleepEx(INFINITE, true);
    } else {
      std::cerr << "Failed to notify service status change: " << GetLastError() << std::endl;
      break;
    }
  }
  CloseServiceHandle(service);
  CloseServiceHandle(service_manager);
  m_running.store(false);
}

void CALLBACK ConnectionStatusObserver::ServiceNotifyCallback(void* ptr) {
  SERVICE_NOTIFY* serviceNotify = static_cast<SERVICE_NOTIFY*>(ptr);
  ConnectionStatusObserver* instance = static_cast<ConnectionStatusObserver*>(serviceNotify->pContext);

  if (!instance || serviceNotify->dwNotificationStatus != ERROR_SUCCESS) {
    std::cerr << "Service notification failed: " << serviceNotify->dwNotificationStatus << std::endl;
    return;
  }

  auto service_status = &serviceNotify->ServiceStatus;
  auto status = ConnectionStatusFromWinSvcState(service_status->dwCurrentState);

  if (instance->sink_) {
    instance->sink_->Success(flutter::EncodableValue(ConnectionStatusToString(status)));
  }
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> ConnectionStatusObserver::OnListenInternal(
    const flutter::EncodableValue* arguments, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> ConnectionStatusObserver::OnCancelInternal(
    const flutter::EncodableValue* arguments) {
  if (sink_) {
    sink_.reset();
  }

  return nullptr;
}

}  // namespace wireguard_dart
