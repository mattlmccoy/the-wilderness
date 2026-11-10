<!-- Matt's original brief, November 2026, verbatim. -->

CHRIST IN THE WILDERNESS

A Spatially Aware, Interactive Home Art Installation

Technical and Creative Development Brief | November 2026

1. Project Vision

Develop a premium, interactive projection-mapping experience centered on a physical reproduction of Christ in the Wilderness (c. 1515–1520) by Moretto da Brescia, held by the Metropolitan Museum of Art.

The painting will serve as a centerpiece in a private residence. An existing XGIMI projector points toward the wall, with an Apple TV connected via HDMI.

The goal is to transform the painting into a subtly interactive work of art, using precisely mapped light, motion, typography, and spatial storytelling to reveal its details, symbolism, and historical context.

The experience should feel like a natural extension of the physical artwork, not software projected onto a wall.

The guiding principle: exceptional design, invisible technology.

This is not a museum installation, educational kiosk, or conventional augmented-reality application. It is a bespoke residential experience that should feel beautiful, intimate, effortless, and thoughtfully integrated into the home.

The physical painting must remain the centerpiece. The technology should enhance it, never compete with it.

⸻

2. Existing Hardware and Constraints

Available hardware

* Projector: Believed to be XGIMI Elfin Flip. Exact model and firmware version need verification.
* Projector camera: Built-in optical sensor/camera used for autofocus and automatic geometric correction. Its accessibility to third-party applications is unknown.
* Media player: Apple TV, exact generation to be confirmed.
* Development computer: Mac capable of running Xcode.
* Optional calibration device: iPhone.
* Artwork: Physical reproduction of Christ in the Wilderness. Exact size, material, and framing are to be confirmed.
* Installation: The projector is not permanently mounted but generally remains stationary.
* Network: Home Wi-Fi.

Non-negotiable constraints

1. The Apple TV must retain all normal streaming and entertainment functionality.
2. The installation must not require additional permanently installed hardware.
3. No external camera, Raspberry Pi, or dedicated computing device.
4. An iPhone may be used temporarily for calibration but must not be required during normal operation.
5. The Apple TV remote should be the primary interaction device.
6. Calibration must be fast, repeatable, and preferably automatic.
7. The application must function without continuous camera tracking once alignment is established.
8. Avoid modifying projector firmware unless there is a compelling and well-supported reason.

⸻

3. Software Architecture

Preferred architecture: Native tvOS application

The first choice is a dedicated Apple TV application developed in Swift.

The application should launch naturally from the Apple TV home screen, support the Siri Remote, and behave like a polished native Apple-platform experience.

Use:

* Swift and SwiftUI for application structure and controls.
* SpriteKit, Core Animation, or Metal for rendering and animation, based on technical evaluation.
* A custom spatial transformation layer for projection mapping.
* Local persistence for calibration and content.
* Optional local-network communication with an iPhone companion application.

The application should be fullscreen, with no persistent system-style navigation visible during the artwork experience.

The Apple TV remote must support all essential interactions.

Alternative architecture: XGIMI software integration

Investigate whether the XGIMI’s operating system, built-in camera, geometric correction system, or software APIs could meaningfully improve the experience.

Areas to investigate:

* Exact projector operating system and software architecture.
* Availability of documented developer APIs.
* Camera access from third-party applications.
* Access to existing keystone or geometric calibration information.
* Android application installation or sideloading, if supported by the model.
* Network communication between projector software and the Apple TV.
* Whether an XGIMI-side helper application could expose useful camera or calibration data without altering firmware.

An XGIMI-side helper should be considered only if it provides a clear advantage and can coexist reliably with the Apple TV HDMI input.

Do not assume an application running on the projector can overlay graphics onto the Apple TV HDMI signal or access protected system camera services.

Architecture decision criteria

Evaluate options based on:

1. User experience and visual quality.
2. Reliability.
3. Hardware compatibility.
4. Calibration accuracy.
5. Ease of maintenance.
6. Development complexity.
7. Preservation of normal Apple TV functionality.

Default to native tvOS unless evidence supports a better alternative.

⸻

4. Spatial Registration and Calibration

Accurate projection mapping is a foundational requirement.

The software must align digital masks, highlights, and annotations with the physical painting, even when the projector is angled relative to the wall.

Because the projector rarely moves, continuous tracking is not essential. The system should instead establish accurate registration, save it, and restore it automatically.

Priority A: XGIMI camera-assisted calibration

Investigate the feasibility of using the projector’s existing camera or optical sensor.

Desired capabilities:

* Capture the painting and surrounding wall.
* Identify the painting through feature matching or boundary detection.
* Determine the painting’s position and orientation.
* Estimate the transformation needed for accurate projection.
* Automatically restore alignment after small changes.

Confirm whether the camera is accessible through documented or reasonably supported APIs.

Do not assume the camera is available to third-party applications merely because it exists physically.

The camera-to-projector relationship must be calibrated or otherwise established. A camera image alone does not directly provide projector coordinates.

If accessing the camera requires invasive firmware modification, unsupported system privileges, or substantial reliability compromises, move to the iPhone approach.

Priority B: iPhone-assisted automatic calibration

If XGIMI camera access is impractical, implement an iPhone-assisted calibration workflow.

The iPhone is used only during calibration.

Desired user experience

1. Open The Wilderness on Apple TV.
2. Select Calibrate.
3. The projector displays a carefully designed calibration pattern.
4. Open the iPhone companion or calibration interface.
5. Point the phone toward the painting and projected pattern.
6. Computer vision identifies the painting and calibration markers.
7. The system computes the required spatial transformation.
8. Calibration parameters are transmitted to the Apple TV.
9. The installation immediately displays an alignment preview.
10. The user confirms or makes minor adjustments.

Target a process lasting approximately 10–20 seconds under favorable conditions.

The experience should feel as effortless as scanning a document or configuring an Apple Home device.

Computer vision approach

Evaluate:

* Apple Vision for image-feature detection.
* OpenCV for feature matching and homography estimation.
* ArUco or AprilTag markers for robust projected reference-point detection.
* Detection of painting boundaries and/or reference-image features.
* RANSAC-based estimation to reject incorrect feature matches.
* Calibration confidence and reprojection error.

The iPhone camera must observe both the physical painting and known projected reference points.

This allows the system to estimate the relationship between the painting and the projector output through their common camera-image coordinate system.

Account for camera distortion, geometric correction, and potential registration errors.

Priority C: Manual calibration

Provide a reliable fallback requiring no camera.

Display four adjustable corner markers corresponding to the painting.

The user aligns them with the physical artwork using the Apple TV remote.

The application calculates a projective transformation and saves the result.

Support:

* Coarse and fine adjustments.
* Saved calibration profiles.
* Rapid restoration.
* Visual verification.
* Reset and recalibration.

Manual calibration should remain available even if automatic calibration works.

Calibration persistence

Store:

* Painting corner positions.
* Projector-output resolution.
* Transformation matrix.
* Calibration confidence, if available.
* Relevant projector configuration information.
* Timestamp and version.
* Optional named profiles.

The system should detect or gracefully handle changes in display resolution or geometry.

Automatic recalibration is not required every time the application launches if the existing calibration remains valid.

⸻

5. Projection Mapping and Rendering Engine

Develop a reusable rendering system capable of projecting visual elements onto specific locations within and around the physical painting.

Required capabilities

* Perspective-correct image mapping.
* Four-point homography transformations.
* Polygon masks.
* Alpha masks for irregular shapes.
* Animated outlines and selective illumination.
* Spatially positioned typography.
* Smooth opacity and color transitions.
* Layered compositing.
* Accurate coordinate mapping between reference image and physical artwork.
* Animation timelines.
* Saved calibration.
* Reliable rendering at the Apple TV’s output resolution.

Coordinate systems

Clearly define and separate:

1. Reference artwork coordinates.
2. Normalized annotation coordinates.
3. Projector-output coordinates.
4. Camera-image coordinates, when applicable.
5. Physical wall and painting geometry.

Avoid mixing coordinate spaces throughout the codebase.

Projection limitations

Account for:

* Nonzero projector black levels.
* Residual illumination when rendering black.
* Surface reflectivity and texture.
* Frame shadows.
* Ambient room lighting.
* Optical distortion.
* Keystone correction.
* Projector autofocus.
* Projector resolution and brightness.

Do not assume perfect alignment or contrast.

The system should prioritize visual quality on the actual wall rather than only in a simulator.

⸻

6. Creative Direction and Design Language

Design quality is as important as technical functionality.

The installation should feel premium, contemporary, and unusually thoughtful.

Desired aesthetic

* Editorial rather than instructional.
* Cinematic rather than theatrical.
* Sophisticated rather than ornate.
* Minimal without feeling sterile.
* Warm rather than technologically cold.
* Quietly expressive rather than flashy.

The design should draw from the painting’s colors, composition, and historical atmosphere without reproducing Renaissance ornamentation literally.

Visual references

Consider the sensibilities of:

* High-end editorial art direction.
* Luxury art and architecture publications.
* Apple’s best spatial and motion-design work.
* Contemporary architectural lighting.
* Fine-art book typography.
* Experimental motion-graphics studios.
* Premium interactive installations.

Do not copy an existing interface. Develop a coherent original visual language.

Typography

Typography should be a major design element.

Explore sophisticated serif typography for narrative content, potentially paired with a restrained contemporary sans-serif for secondary information.

Consider:

* Beautiful proportions.
* Generous spacing.
* Strong typographic hierarchy.
* Deliberate line lengths.
* Elegant entrance and exit animations.
* Carefully controlled placement on the wall.

Text should appear integrated with the physical space.

Color

Develop a palette from the original painting.

Potential directions:

* Warm ivory.
* Muted gold.
* Deep charcoal.
* Earthy green.
* Desaturated blue.
* Warm stone.

Avoid saturated UI colors, neon outlines, and generic glowing effects.

Motion

Movement should be purposeful.

Explore:

* Slow reveals.
* Soft transitions.
* Subtle directional lighting.
* Gentle focus shifts.
* Delicate tracing of forms.
* Typography that appears with deliberate pacing.
* Spatial transitions that follow the painting’s composition.

Avoid constant motion, excessive particles, or dramatic animations that distract from the artwork.

Invisible interface

The installation should display no visible interface when inactive.

Controls should appear only when needed.

The user should never feel as though they are navigating a conventional television application projected onto a wall.

⸻

7. Core Experiences

Experience A: Explore

The user selects individual details within the painting.

A selected element becomes subtly illuminated, while interpretive content appears in the surrounding projection area.

Examples:

The lion: Highlight the animal and reveal its traditional associations with strength, kingship, and the reconciliation of nature.

The basilisk: Reveal the small dragon-like creature and its connections to evil, temptation, and Psalm 91.

The angels: Illuminate the heavenly figures and explain their relationship to the Gospel accounts.

Christ: Draw attention to his posture, contemplative expression, and the significance of his forty-day fast.

The interactions should feel like discoveries rather than conventional menu selections.

Experience B: Unfold

A guided, cinematic narrative lasting approximately five minutes.

Suggested sequence:

1. The wilderness.
2. Forty days of fasting.
3. Christ’s humanity and contemplation.
4. Wild animals and the restoration of Eden.
5. The basilisk and the symbolism of evil.
6. Angels and divine assistance.
7. The missing portions of the original painting.
8. The painting’s broader spiritual meaning.

The experience should move attention through the artwork using light, motion, and spatial typography.

Narration may be optional.

Experience C: Stillness

A subtle ambient experience suitable for an ordinary evening at home.

The painting remains dominant.

Occasional, almost imperceptible illumination may emphasize different details.

Avoid anything resembling a screensaver.

This mode should be optional and should not require the projector to remain on continuously.

Experience D: Context

An interactive visual essay exploring the world in which Moretto painted the work.

Topics include:

* Brescia around 1515.
* Venetian artistic influence.
* Renaissance religious devotion.
* Christianity before and during the Reformation.
* The role of symbolic animals in Christian art.
* The painting’s subsequent alteration and conservation.

Potential visual elements include a beautifully designed animated map of Renaissance Italy and archival imagery.

The result should feel like an exceptionally designed editorial feature, not a history lecture.

⸻

8. Apple TV Remote Interaction

The Siri Remote is the primary controller.

The experience must be fully functional without an iPhone.

Explore a navigation model based on:

* Directional input to move between artwork details.
* Select to reveal an interpretation.
* Back to return to the painting.
* Play/Pause to control guided sequences.
* A minimal method for switching experiences.
* A discreet calibration/settings interface.

Consider spatial navigation based on the physical locations of elements in the painting rather than a conventional vertical list.

For example, pressing right might move the selection from a creature on the left to Christ on the right.

Provide subtle visual feedback so the user always understands which element is selected.

The remote should feel like a natural way to interact with the painting.

Avoid excessive navigation depth and complicated gestures.

⸻

9. Optional iPhone Companion

An iPhone companion application could serve two purposes.

Calibration

Provide camera-assisted automatic registration as described earlier.

Direct artwork interaction

Display a high-resolution reproduction of the painting.

The user taps a creature or detail directly on the phone.

The corresponding physical element illuminates on the wall.

Longer explanations could appear on the phone, preserving the projected installation’s minimal aesthetic.

The iPhone companion should communicate locally with the Apple TV.

Evaluate Bonjour discovery, Network.framework, or other appropriate Apple-platform networking solutions.

The companion should be optional during normal use.

⸻

10. Content and Annotation System

Separate interpretive content from rendering logic.

Use structured data, such as JSON, to define each annotated element.

Each element should contain:

* Unique identifier.
* Title.
* Short interpretation.
* Extended interpretation.
* Biblical references.
* Historical context.
* Evidence classification.
* Normalized artwork coordinates.
* Polygon or alpha-mask geometry.
* Preferred text placement.
* Optional animation properties.

Historical accuracy

The content should distinguish:

1. Documented features and identifications.
2. Established Christian iconographic traditions.
3. Plausible but uncertain interpretations.
4. Speculative reconstructions.

Avoid presenting every animal as having one definitive symbolic meaning.

Use the Metropolitan Museum of Art’s collection information and scholarly sources wherever possible.

Annotation editor

Consider building a simple development tool for defining polygons, masks, and anchor points over the high-resolution artwork.

This will be more efficient than manually entering coordinates in source code.

The annotation system should eventually be reusable for other artworks, but do not overengineer multi-artwork support in the first version.

⸻

11. Development Roadmap

Phase 1: Hardware and architecture validation

Confirm:

* Exact XGIMI model and firmware.
* Apple TV generation and tvOS version.
* Projector operating system.
* Camera accessibility.
* Available XGIMI APIs.
* HDMI and geometric correction behavior.
* Practical tvOS rendering options.

Compare native tvOS and XGIMI-assisted architectures.

Deliverable: A clear architecture recommendation supported by verified technical constraints.

Phase 2: Projection-mapping proof of concept

Build a minimal native tvOS application that:

* Displays calibration markers.
* Accepts remote input.
* Calculates a homography.
* Saves calibration.
* Projects a test shape accurately onto a physical feature.
* Restores calibration after relaunch.

Success criterion: Accurate, repeatable alignment of a projected highlight with the physical painting.

Phase 3: Automatic calibration

Implement the preferred camera-assisted workflow.

Use the XGIMI camera if accessible and practical.

Otherwise, implement iPhone-assisted calibration.

Retain manual calibration as a fallback.

Success criterion: Restore accurate alignment after a small projector movement with minimal user effort.

Phase 4: Design prototype

Develop the visual language and interaction system.

Implement three polished examples:

* Christ.
* Basilisk.
* Angels.

Prioritize visual quality, motion, and spatial composition.

Success criterion: A cohesive, beautiful interaction that feels appropriate for a premium residential installation.

Phase 5: Complete artwork experience

Add:

* Full annotation set.
* Guided narrative.
* Historical context.
* Ambient mode.
* Refined remote navigation.
* Optional narration.

Phase 6: Refinement and optional enhancements

Explore:

* iPhone direct-selection interface.
* Improved camera tracking.
* Dynamic wall-aware typography placement.
* Automatic ambient-light adjustment where supported.
* Multiple artwork profiles.

⸻

12. Immediate Instructions to Claude

Act as a senior Apple-platform engineer, computer-vision engineer, creative technologist, and exceptional digital product designer.

Treat this as a bespoke residential art installation with a very high standard of visual design.

The preferred implementation is a native Apple TV application controlled by the Siri Remote.

Investigate XGIMI software integration, particularly camera access and calibration information, but do not assume those capabilities exist.

Respect the constraint against additional permanently installed hardware.

First:

1. Verify the hardware assumptions.
2. Evaluate native tvOS rendering and projection mapping.
3. Investigate XGIMI camera and software accessibility.
4. Recommend the simplest reliable calibration architecture.
5. Explain technical limitations and risks.

Then:

1. Propose the Xcode project structure.
2. Define the rendering and coordinate-transformation architecture.
3. Design the remote-based calibration interface.
4. Implement a working projection-mapping prototype.
5. Establish a foundation for an exceptionally polished visual experience.

Do not begin by building a large application framework or creating dozens of placeholder screens.

Start with a working prototype that maps one digital shape accurately onto the physical artwork.

Once spatial registration works, develop the experience with the attention to detail expected of a high-end interactive design studio.

Final creative objective

Make a five-hundred-year-old painting feel quietly alive.

The result should be something a guest discovers unexpectedly, not a piece of technology demanding attention.

It should feel as though the artwork has always contained these hidden layers, and the projection simply gives them permission to emerge.
