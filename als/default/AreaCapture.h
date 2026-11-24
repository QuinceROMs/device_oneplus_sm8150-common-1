/*
 * Copyright (C) 2021-2024 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <aidl/vendor/lineage/oplus_als/BnAreaCapture.h>
#include <binder/IBinder.h>
#include <ui/Rect.h>
#include <mutex>

namespace aidl {
namespace vendor {
namespace lineage {
namespace oplus_als {

class AreaCapture : public BnAreaCapture {
  public:
    AreaCapture();
    ndk::ScopedAStatus getAreaBrightness(AreaRgbCaptureResult* _aidl_return) override;

  private:
    ::android::sp<::android::IBinder> getInternalDisplayToken();
    void forgetInternalDisplayToken();

    ::android::Rect m_screenshot_rect;
    std::mutex m_display_token_mutex;
    ::android::sp<::android::IBinder> m_display_token;
};

}  // namespace oplus_als
}  // namespace lineage
}  // namespace vendor
}  // namespace aidl
