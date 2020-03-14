//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

class Producer<Element> : Observable<Element> {
    override init() {
        super.init()
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            // The returned disposable needs to release all references once it was disposed.
            let disposer = SinkDisposer()
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            // Marked by Xavier:
            // `self._state` will be 10b(`sinkAndSubscriptionSet`)
            disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

            return disposer
        }
        else {
            return CurrentThreadScheduler.instance.schedule(()) { _ in
                let disposer = SinkDisposer()
                let sinkAndSubscription = self.run(observer, cancel: disposer)
                disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

                return disposer
            }
        }
    }

    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final class SinkDisposer: Cancelable {
    private enum DisposeState: Int32 {
        case disposed = 1
        case sinkAndSubscriptionSet = 2
    }

    private let _state = AtomicInt(0)
    private var _sink: Disposable?
    private var _subscription: Disposable?

    var isDisposed: Bool {
        return isFlagSet(self._state, DisposeState.disposed.rawValue)
    }

    func setSinkAndSubscription(sink: Disposable, subscription: Disposable) {
        // Marked by Xavier:
        // assign sink and subscription to self._sink and self._subscription respectively
        self._sink = sink
        self._subscription = subscription
    
        // Marked by Xavier:
        //
        // - if `self._state` equals to 00b or 10b(`.sinkAndSubscriptionSet`),
        //   the new value of `self._state` will be 10b(`.sinkAndSubscriptionSet`)
        // - if original value equals to 01b(`.disposed`),
        //   the new value of `self._state` will be 11b
        // new value is store in `self._state`, `previousState` as name indicated is the original value
        let previousState = fetchOr(self._state, DisposeState.sinkAndSubscriptionSet.rawValue)
        // previousStatus == .sinkAndSubscriptionSet
        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            rxFatalError("Sink and subscription were already set")
        }
    
        // Marked by Xavier:
        // previousStatus == .disposable
        if (previousState & DisposeState.disposed.rawValue) != 0 {
            sink.dispose()
            subscription.dispose()
            self._sink = nil
            self._subscription = nil
        }
    }

    func dispose() {
        // Marked by Xavier:
        //
        // - if `self._state` equals to 00b or 01b(`.disposed`),
        //   the new value of `self._state` will be 01b(`.disposed`)
        // - if `self._state` equals to 10b(`.sinkAndSubscriptionSet`),
        //   the new value of `self._state` will be 11b
        let previousState = fetchOr(self._state, DisposeState.disposed.rawValue)
    
        // Marked by Xavier:
        // previousStatus == .disposable
        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }
    
        // Marked by Xavier:
        // previousStatus == .sinkAndSubscriptionSet
        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            guard let sink = self._sink else {
                rxFatalError("Sink not set")
            }
            guard let subscription = self._subscription else {
                rxFatalError("Subscription not set")
            }

            sink.dispose()
            subscription.dispose()

            self._sink = nil
            self._subscription = nil
        }
    }
}
