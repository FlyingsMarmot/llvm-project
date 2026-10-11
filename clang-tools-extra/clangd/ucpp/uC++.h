// Portable declarations for clangd analysis of uC++ 7.0.0 programs.
// The public signatures below mirror the bundled runtime's kernel/uC++.h.
// This is not an executable runtime or an ABI-compatible replacement: build
// programs with the real uC++ toolchain. Platform internals are intentionally
// omitted so editor startup does not depend on Linux unwind/thread APIs.
#pragma once

#ifdef __cplusplus
#include <cstddef>
#include <cstdint>
#include <uCalendar.h>
#include <uDefault.h>
#include <uRandom.h>

class uCluster;
class uBaseTask;
class uProcessor;

class uBaseCoroutine {
protected:
  void resume();
  void suspend();

public:
  enum State { Start, Inactive, Active, Halt };
  uBaseCoroutine(const uBaseCoroutine &) = delete;
  uBaseCoroutine(uBaseCoroutine &&) = delete;
  uBaseCoroutine &operator=(const uBaseCoroutine &) = delete;
  uBaseCoroutine &operator=(uBaseCoroutine &&) = delete;
  uBaseCoroutine();
  uBaseCoroutine(unsigned int stackSize);
  uBaseCoroutine(void *storage, unsigned int storageSize);
  const char *setName(const char *name);
  const char *getName() const;
  State getState() const;
  uBaseCoroutine &starter() const;
  uBaseCoroutine &resumer() const;
};

class uBaseTask : public uBaseCoroutine {
public:
  static void yield();
  static void yield(std::size_t times);
  static void sleep(uDuration duration);
  static void sleep(uTime time);
};

class uCondition {
public:
  uCondition();
  ~uCondition();
  uCondition(const uCondition &) = delete;
  uCondition(uCondition &&) = delete;
  uCondition &operator=(const uCondition &) = delete;
  uCondition &operator=(uCondition &&) = delete;
  void wait();
  void wait(std::uintptr_t info);
  bool signal();
  bool signalBlock();
  bool empty() const;
  std::uintptr_t front() const;
};

class uMutexLock {
public:
  uMutexLock();
  uMutexLock(const uMutexLock &) = delete;
  uMutexLock(uMutexLock &&) = delete;
  uMutexLock &operator=(const uMutexLock &) = delete;
  uMutexLock &operator=(uMutexLock &&) = delete;
  void acquire();
  bool tryacquire();
  void release();
};

class uOwnerLock : public uMutexLock {
public:
  uOwnerLock(const uOwnerLock &) = delete;
  uOwnerLock(uOwnerLock &&) = delete;
  uOwnerLock &operator=(const uOwnerLock &) = delete;
  uOwnerLock &operator=(uOwnerLock &&) = delete;
  uOwnerLock();
  unsigned int times() const;
  uBaseTask *owner() const;
  void acquire();
  bool tryacquire();
  void release();
};

class uProcessor {
public:
  uProcessor(const uProcessor &) = delete;
  uProcessor(uProcessor &&) = delete;
  uProcessor &operator=(const uProcessor &) = delete;
  uProcessor &operator=(uProcessor &&) = delete;
  uProcessor(unsigned int ms = uDefaultPreemption(),
             unsigned int spin = uDefaultSpin());
  uProcessor(bool detached, unsigned int ms = uDefaultPreemption(),
             unsigned int spin = uDefaultSpin());
  uProcessor(uCluster &cluster, unsigned int ms = uDefaultPreemption(),
             unsigned int spin = uDefaultSpin());
  uProcessor(uCluster &cluster, bool detached,
             unsigned int ms = uDefaultPreemption(),
             unsigned int spin = uDefaultSpin());
  ~uProcessor();
  uCluster &setCluster(uCluster &cluster);
  uCluster &getCluster() const;
};

uBaseCoroutine &uThisCoroutine();
uBaseTask &uThisTask();
uProcessor &uThisProcessor();
uCluster &uThisCluster();
#endif
