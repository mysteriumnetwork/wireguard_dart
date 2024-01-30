#include "connection_status_observer.h"
#include "connection_status.h"

namespace wireguard_dart {

ConnectionStatusObserver::ConnectionStatusObserver() {}

ConnectionStatusObserver::~ConnectionStatusObserver() {}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> ConnectionStatusObserver::OnListenInternal(
    const flutter::EncodableValue* arguments, std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
        this->sink = std::move(events);
        sink->Success(flutter::EncodableValue(ConnectionStatusToString(ConnectionStatus::disconnected)));
        return nullptr;
    }

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> ConnectionStatusObserver::OnCancelInternal(
    const flutter::EncodableValue* arguments) {
        this->sink.reset();
        return nullptr;
    }

}  // namespace wireguard_dart
