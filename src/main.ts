import * as rm from "https://deno.land/x/remapper@4.2.3/src/mod.ts"
import * as bundleInfo from '../bundleinfo.json' with { type: 'json' }
import { SetMaterialProperty } from "https://deno.land/x/remapper@4.2.3/src/internals/mod.ts";

const pipeline = await rm.createPipeline({ bundleInfo })

const bundle = rm.loadBundle(bundleInfo)
const materials = bundle.materials
const prefabs = bundle.prefabs

// ----------- { SCRIPT } -----------

async function doMap(file: rm.DIFFICULTY_NAME, chromaOnly: boolean = false) {
    const map = await rm.readDifficultyV3(pipeline, file);

    if (!chromaOnly) map.require("Vivify", true);
    map.suggest("Chroma", true);
    if (!chromaOnly) map.require("Noodle Extensions", true);

    /// ---- { FUNCTIONS } -----
    function getEventColor(event: rm.LightEvent): rm.ColorVec {
        if (event.chromaColor) {
            const c = event.chromaColor
            return [c[0], c[1], c[2], (c[3] ?? 1) * event.floatValue];
        }// If the event has a Chroma color, return that.
        else { // Otherwise get the regular event color
            if (event.value == 5) {
                const c = map.difficultyInfo.unsafeCustomData?._envColorLeft; // Get left color from map.
                return c ? [c.r, c.g, c.b, (c.a ?? 1) * event.floatValue] : [0, 0, 0, 0]; // Convert it into a rm.ColorVec. If no color is set in the difficulty, return black. If no alpha, return alpha 1.
            }
            if (event.value == 1) {
                const c = map.difficultyInfo.unsafeCustomData?._envColorRight; // Get right color from map.
                return c ? [c.r, c.g, c.b, (c.a ?? 1) * event.floatValue] : [0, 0, 0, 0]; // Convert it into a rm.ColorVec. If no color is set in the difficulty, return black. If no alpha, return alpha 1.
            }
            if (event.value == 9) {
                const c = map.difficultyInfo.unsafeCustomData?._envColorWhite; // Get white color from map.
                return c ? [c.r, c.g, c.b, (c.a ?? 1) * event.floatValue] : [0, 0, 0, 0]; // Convert it into a rm.ColorVec. If no color is set in the difficulty, return black. If no alpha, return alpha 1.
            }
            else return [0, 0, 0, 0]
        }
    }

    // No lightID means the event targets every light of that type
    function targetsLight(event: rm.LightEvent, id: number) {
        if (event.lightID === undefined) return true;
        return [event.lightID].flat().includes(id);
    }

    /// ---- { ENVIRONMENT } -----

    rm.environmentRemoval(map, [
        "RailingFull",
        "RailingCurveF",
        "LeftRail",
        "RightRail",
        "PlayersPlace",
        "Clouds",
        "Waterfall",
        "Mountains",
        "Smoke",
        "Rain",
        "LightRailingSegment",
        "BottomPairLasers",
        "LeftFarRail",
        "RightFarRail"
    ], "Contains");
    rm.environment(map, "Smoke", "Contains").scale = [10, 10, 10]

    rm.setRenderingSettings(map, {
        qualitySettings: {
            realtimeReflectionProbes: rm.BOOLEAN.True,
            shadows: rm.SHADOWS.HardOnly,
            shadowDistance: 64,
            shadowResolution: rm.SHADOW_RESOLUTION.High,
            softParticles: rm.BOOLEAN.True,
        },
        beat: 0
    })

    rm.setCameraProperty(map, 0, { depthTextureMode: ['Depth'] })

    rm.setGlobalProperty(map, 0, [
        { id: "_TrackLaneYPosition", type: "Float", value: 0 }
    ])

    prefabs.environment.instantiate(map, 0);
    prefabs.skybox.instantiate(map, 0);
    prefabs.laserl1.instantiate(map, 0);
    prefabs.laserl2.instantiate(map, 0);
    prefabs.laserl3.instantiate(map, 0);
    prefabs.laserr1.instantiate(map, 0);
    prefabs.laserr2.instantiate(map, 0);
    prefabs.laserr3.instantiate(map, 0);

    rm.environment(map, {
        id: "s.[0]PillarL",
        lookupMethod: "EndsWith",
        "localRotation": [
            60,
            90,
            -50
        ],
        "localPosition": [
            -9.5,
            2.5,
            -11.5
        ]
    })

    /// ---- { EVENTS } -----

    // Cave laser speed setup
    if (!chromaOnly) {
        materials.laserl1.set(map, { _Speed: 0 }, 0);
        materials.laserl2.set(map, { _Speed: 0 }, 0);
        materials.laserl3.set(map, { _Speed: 0 }, 0);
        materials.laserr1.set(map, { _Speed: 0 }, 0);
        materials.laserr2.set(map, { _Speed: 0 }, 0);
        materials.laserr3.set(map, { _Speed: 0 }, 0);
    }

    // Cave laser color setup
    if (!chromaOnly) {
        materials.laserl1.set(map, { _Color: [0, 0, 0, 0] }, 0);
        materials.laserl2.set(map, { _Color: [0, 0, 0, 0] }, 0);
        materials.laserl3.set(map, { _Color: [0, 0, 0, 0] }, 0);
        materials.laserr1.set(map, { _Color: [0, 0, 0, 0] }, 0);
        materials.laserr2.set(map, { _Color: [0, 0, 0, 0] }, 0);
        materials.laserr3.set(map, { _Color: [0, 0, 0, 0] }, 0);
    }

    // Cave ores brightness setup
    if(!chromaOnly) {
        materials.orel1.set(map, {_Brightness: 0}, 0);
        materials.orel2.set(map, {_Brightness: 0}, 0);
        materials.orel3.set(map, {_Brightness: 0}, 0);
        materials.orel4.set(map, {_Brightness: 0}, 0);
        materials.orel5.set(map, {_Brightness: 0}, 0);
        materials.orel6.set(map, {_Brightness: 0}, 0);
        materials.orel7.set(map, {_Brightness: 0}, 0);
        materials.orel8.set(map, {_Brightness: 0}, 0);
        materials.orel9.set(map, {_Brightness: 0}, 0);
        materials.orer1.set(map, {_Brightness: 0}, 0);
        materials.orer2.set(map, {_Brightness: 0}, 0);
        materials.orer3.set(map, {_Brightness: 0}, 0);
        materials.orer4.set(map, {_Brightness: 0}, 0);
        materials.orer5.set(map, {_Brightness: 0}, 0);
        materials.orer6.set(map, {_Brightness: 0}, 0);
        materials.orer7.set(map, {_Brightness: 0}, 0);
        materials.orer8.set(map, {_Brightness: 0}, 0);
        materials.orer9.set(map, {_Brightness: 0}, 0);
    }

    // Material to LightId mapping
    if (!chromaOnly) map.lightEvents.forEach(event => {
        // Left lasers
        if(event.type == 1 && targetsLight(event, 1)) {
            materials.laserl1.set(map, { _Color: getEventColor(event) }, event.beat);
        }
        if(event.type == 6 && targetsLight(event, 1)) {
            materials.laserl2.set(map, { _Color: getEventColor(event) }, event.beat);
        }
        if (event.type == 7 && targetsLight(event, 1)) {
            materials.laserl3.set(map, { _Color: getEventColor(event) }, event.beat);
        }

        // Right lasers
        if(event.type == 1 && targetsLight(event, 2)) {
            materials.laserr1.set(map, { _Color: getEventColor(event) }, event.beat);
        }
        if(event.type == 6 && targetsLight(event, 2)) {
            materials.laserr2.set(map, { _Color: getEventColor(event) }, event.beat);
        }
        if (event.type == 7 && targetsLight(event, 2)) {
            materials.laserr3.set(map, { _Color: getEventColor(event) }, event.beat);
        }

        // Left ores
        if(event.type == 10 && targetsLight(event, 1)) materials.orel1.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 2)) materials.orel2.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 3)) materials.orel3.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 4)) materials.orel4.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 5)) materials.orel5.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 6)) materials.orel6.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 7)) materials.orel7.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 8)) materials.orel8.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 10 && targetsLight(event, 9)) materials.orel9.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);

        // Right ores
        if(event.type == 11 && targetsLight(event, 1)) materials.orer1.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 2)) materials.orer2.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 3)) materials.orer3.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 4)) materials.orer4.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 5)) materials.orer5.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 6)) materials.orer6.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 7)) materials.orer7.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 8)) materials.orer8.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
        if(event.type == 11 && targetsLight(event, 9)) materials.orer9.set(map, {_Brightness: getEventColor(event)[3]}, event.beat);
    })

    // Map laser speed events to laser material speed value
    if (!chromaOnly) map.laserSpeedEvents.forEach(event => {
        if (event.type == 12) {
            const speed = event.value;
            materials.laserl1.set(map, { _Speed: speed }, event.beat);
            materials.laserl2.set(map, { _Speed: speed }, event.beat);
            materials.laserl3.set(map, { _Speed: speed }, event.beat);
        }
        if (event.type == 13) {
            const speed = event.value;
            materials.laserr1.set(map, { _Speed: speed }, event.beat);
            materials.laserr2.set(map, { _Speed: speed }, event.beat);
            materials.laserr3.set(map, { _Speed: speed }, event.beat);
        }
    })

    /*
    // Assign all notes to a track
    if(!chromaOnly) map.allNotes.forEach(note => {
        note.track.add("allNotes")
    })

    // Apply custom note prefab to all notes
    if(!chromaOnly) rm.assignObjectPrefab(map, {
        colorNotes: {
            track: "allNotes",
            asset: prefabs.customnote.path,
            debrisAsset: prefabs.customnotedebris.path,
            anyDirectionAsset: prefabs.customnotedot.path
        },
        chainHeads: {
            track: "allNotes",
            asset: prefabs.customchain.path,
            debrisAsset: prefabs.customchaindebris.path
        },
        chainLinks: {
            track: "allNotes",
            asset: prefabs.customchainlink.path,
            debrisAsset: prefabs.customchainlinkdebris.path
        }
    })
        */
}

await Promise.all([
    doMap('ExpertPlusStandard'),
])

// ----------- { OUTPUT } -----------

pipeline.export({
    outputDirectory: '../OutputMaps/harvest sky'
})
