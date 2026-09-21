-- Placeholder. A completed capture leaves this empty.
--
-- If a run is interrupted -- the server rate-limits emotes, so a long run can
-- lose a stretch of replies -- regenerate this file from the partial results
-- with build_captured.py and use /emotecapture resume. SavedVariables are
-- written but never restored on the Forever beta, so the tool cannot read back
-- its own earlier output; baking it into an addon file is the way around that,
-- because addon files do load normally.

EmoteCapturePrevious = nil
EmoteCapturePreviousTarget = nil
