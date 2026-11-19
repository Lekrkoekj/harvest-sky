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



    /// ---- { ENVIRONMENT } -----

    rm.environmentRemoval(map, [
        "RailingFull",
        "RailingCurveF",
        "LeftRail",
        "RightRail",
        "PlayersPlace",
        "Clouds",
        "Waterfall"
    ], "Contains");
    rm.environment(map, "Smoke", "Contains").scale = [3, 3, 3]

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

    prefabs.environment.instantiate(map, 0);
    prefabs.skybox.instantiate(map, 0);

    /// ---- { EVENTS } -----



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
