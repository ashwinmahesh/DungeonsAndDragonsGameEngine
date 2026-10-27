# Native iOS host contract

The core contains touch input, phone/tablet composition, controller navigation, safe-area and keyboard handling,
mobile rendering budgets, atomic saves, exploration checkpoints, command-level combat continuation and interruption
recovery. Desktop behavior is gated separately and keeps its existing layout and renderer settings.

A host game supplies its autoloads as described in the root README, campaign content and resource paths, the project
and iOS export preset, app identity and icon, signing/export tools, the native iOS utility extension and UI tests.
The extension registers `MobileIOS` dynamically on iOS; desktop never loads it. Its methods cover Files import/share,
haptics, device idiom, reduced motion, assistive-access projection and audio-session foreground activation. The
reference host implements the adapter in its `tools/native_ios` directory. Saved-file names derive from the host's
`application/config/name`, and transfer validation uses the serialized Character model without requiring a roster.

The host's active campaign scene joins `campaign_world`. `MobileLifecycle` only checkpoints a scene in that group,
in exploration mode, with no modal input scope. Practice scenes and title screens must not join it. Checkpoints
use `mobile_checkpoint` beside the home save and never rotate arrival/rest/victory autosaves. Command continuation
uses `combat_recovery`; round-start retry remains a separate slot. Honour keeps one campaign slot. The shared save
format remains 2, with a narrow read alias for the already distributed iOS preview's version-3 envelope.

The iOS host must check out this submodule before import/export and rewrite references to moved resources as
`res://addons/dnd_core/...`. Engine unit tests live here; campaign integration and native XCTest journeys live in
the host. Run its focused tests and required `make check`, plus native phone/tablet journeys against an export of
both pinned commits. Prepared macOS captures, native simulator results and physical-device evidence are distinct.
Neither simulator software-GLES timing nor macOS Mobile/Metal captures qualify device frame rate or thermals.
