#ifndef WIREGUARD_DART_CONNECTION_STATUS_OBSERVER_H
#define WIREGUARD_DART_CONNECTION_STATUS_OBSERVER_H

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <windows.h>

#include <thread>

namespace wireguard_dart {

class ConnectionStatusObserver : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  ConnectionStatusObserver();
  virtual ~ConnectionStatusObserver();
  void StartObserving(std::wstring service_name);
  void StopObserving();
  static void CALLBACK ServiceNotifyCallback(void* ptr);

 protected:
  virtual std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);

  virtual std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments);

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  PSC_NOTIFICATION_REGISTRATION subscription_;
  void StartObservingThreadProc(SC_HANDLE service_manager, SC_HANDLE service);

  void Shutdown();
  std::thread watch_thread;
  std::atomic_bool m_watch_thread_stop;
  std::atomic_bool m_running;
  std::wstring m_service_name;
};

}  // namespace wireguard_dart

#endif
