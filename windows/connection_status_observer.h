#ifndef WIREGUARD_DART_CONNECTION_STATUS_OBSERVER_H
#define WIREGUARD_DART_CONNECTION_STATUS_OBSERVER_H

#include <flutter/event_channel.h>
#include <flutter/encodable_value.h>

namespace wireguard_dart {

class ConnectionStatusObserver : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  ConnectionStatusObserver();
  virtual ~ConnectionStatusObserver();

 protected:
  virtual std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);

  virtual std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments);

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink;
};

}  // namespace wireguard_dart

#endif
