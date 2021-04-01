local hex  = require 'hex'
local util = require 'utility'
local fs   = require 'bee.filesystem'

local mdxparser = hex.define {
    'filetype:c4', -- 4
    'vers:Chunk', -- 3*4
    'chunks:Chunk[?_BufferSize-16]', -- 总大小-16

    Chunk = {
        'header:ChunkHeader', hex.case('header.tag=="VERS"', 'vers:L'),
        hex.case('header.tag=="MODL"', 'modl:MODL'),
        hex.case('header.tag=="SEQS"', 'seqs:SEQS'),
        hex.case('header.tag=="GLBS"', 'glbs:GLBS'),
        hex.case('header.tag=="TEXS"', 'texs:TEXS'),
        hex.case('header.tag=="SNDS"', 'snds:SNDS'),
        hex.case('header.tag=="PIVT"', 'pivt:PIVT'),
        hex.case('header.tag=="MTLS"', 'mtls:MTLS'),
        hex.case('header.tag=="TXAN"', 'txan:TXAN'),
        hex.case('header.tag=="GEOS"', 'geos:GEOS'),
        hex.case('header.tag=="GEOA"', 'geoa:GEOA'),
        hex.case('header.tag=="BONE"', 'bone:BONE'),
        hex.case('header.tag=="LITE"', 'lite:LITE'),
        hex.case('header.tag=="HELP"', 'help:HELP'),
        hex.case('header.tag=="ATCH"', 'atch:ATCH'),
        hex.case('header.tag=="PREM"', 'prem:PREM'),
        hex.case('header.tag=="PRE2"', 'pre2:PRE2'),
        hex.case('header.tag=="RIBB"', 'ribb:RIBB'),
        hex.case('header.tag=="EVTS"', 'evts:EVTS'),
        hex.case('header.tag=="CAMS"', 'cams:CAMS'),
        hex.case('header.tag=="CLID"', 'clid:CLID'),
        -- version>800
        hex.case('header.tag=="BPOS"', 'bpos:BPOS'),
        hex.case('header.tag=="FAFX"', 'fafx:FAFX'),
        hex.case('header.tag=="CORN"', 'corn:CORN')
    },

    MODL = {
        'name:c80', 'animationFileName:c260', 'extent:Extent', 'blendTime:L'
    },
    SEQS = {'sequences:Sequence[header.size/132]'},
    GLBS = {'globalSequences:uint32[header.size/4]'},
    TEXS = {'textures:Texture[header.size/268]'},
    SNDS = {'soundTracks:SoundTrack[header.size/272]'},
    PIVT = {'points:Vector3[header.size/12]'},
    MTLS = {'materials:Material[?header.size]'},
    TXAN = {'animations:TextureAnimation[?header.size]'},
    GEOS = {'geosets:Geoset[?header.size]'},
    GEOA = {'animations:GeosetAnimation[?header.size]'},
    BONE = {'bones:Bone[?header.size]'},
    LITE = {'lights:Light[?header.size]'},
    HELP = {'helpers:Helper[?header.size]'},
    ATCH = {'attachments:Attachment[?header.size]'},
    PREM = {'emitters:ParticleEmitter[?header.size]'},
    PRE2 = {'emitters:ParticleEmitter2[?header.size]'},
    RIBB = {'emitters:RibbonEmitter[?header.size]'},
    EVTS = {'objects:EventObject[?header.size]'},
    CAMS = {'cameras:Camera[?header.size]'},
    CLID = {'shapes:CollisionShape[?header.size]'},
    BPOS = {'count:L', 'bindPose:Pose[count]'},
    FAFX = {'target:c80', 'path:c260'},
    CORN = {'emitters:CornEmitter[?header.size]'},

    uint32 = ':L',
    uint16 = ':I2',
    uint8 = ':I1',
    int32 = ':l',
    ChunkHeader = {'tag:c4', 'size:L'},
    Extent = {'boundsRadius:f', 'minimum:Vector3', 'maximum:Vector3'},
    Vector2 = {"x:f", "y:f"},
    Vector3 = {"x:f", "y:f", "z:f"},
    Vector4 = {"q1:f", "q2:f", "q3:f", "q0:f"},
    Pose = {
        ":f", ":f", ":f", ":f", ":f", ":f", ":f", ":f", ":f", ":f", ":f", ":f"
    },
    Color = {"r:f", "g:f", "b:f"},
    ColorA = {"a:f", "r:f", "g:f", "b:f"},
    Sequence = {
        'name:c80', 'interval:Timeline', 'moveSpeed:f', 'flags:L', 'rarity:f',
        'syncPoint:L', 'extent:Extent'
    },
    Timeline = {"startTime:L", "endTime:L"},
    Texture = {"replaceableId:L", "fileName:c260", "flags:L"},
    SoundTrack = {"fileName:c260", "volume:f", "pitch:f", "flags:L"},
    Material = {
        "inclusiveSize:L", "priorityPlane:L", "flags:L",
        hex.case('vers.vers>800', 'shader:c80'), ":c4", "layersCount:L",
        "layers:Layer[layersCount]"
    },
    Layer = {
        "inclusiveSize:L", "filterMode:L", "shadingFlags:L", "textureId:L",
        "textureAnimationId:L", "coordId:L", "alpha:f",
        hex.case('vers.vers>800', 'emissiveGain:f'),
        hex.case('vers.vers>800', 'fresnelColor:Color'),
        hex.case('vers.vers>800', 'fresnelOpacity:f'),
        hex.case('vers.vers>800', 'fresnelTeamColor:f'),
        "tracks:TracksChunk[?inclusiveSize-4*7]"
    },
    TextureAnimation = {
        "inclusiveSize:L", "tracks:TracksChunk[?inclusiveSize-4]"
    },
    Geoset = {
        "inclusiveSize:L", ":c4", "vertexCount:L",
        "vertexPositions:Vector3[vertexCount]", ":c4", "normalCount:L",
        "vertexNormals:Vector3[vertexCount]", ":c4", "faceTypeGroupsCount:L",
        "faceTypeGroups:uint32[faceTypeGroupsCount]", ":c4",
        "faceGroupsCount:L", "faceGroups:uint32[faceGroupsCount]", ":c4",
        "facesCount:L", "faces:uint16[facesCount]", ":c4",
        "vertexGroupsCount:L", "vertexGroups:uint8[vertexGroupsCount]", ":c4",
        "matrixGroupsCount:L", "matrixGroups:uint32[matrixGroupsCount]", ":c4",
        "matrixIndicesCount:L", "matrixIndices:uint32[matrixIndicesCount]",
        "materialId:L", "selectionGroup:L", "selectionFlags:L",
        hex.case('vers.vers>800', 'lod:L'),
        hex.case('vers.vers>800', 'lodName:c80'), "extent:Extent",
        "extentsCount:L", "sequenceExtents:Extent[extentsCount]", "nextTag1:c4", -- "UVAS"/"TANG"/"SKIN"
        hex.case('vers.vers>800 and nextTag1=="TANG"', 'tangents:Tangents'),
        hex.case('vers.vers>800 and nextTag1=="TANG"', 'nextTag2:c4'),
        hex.case('vers.vers>800 and nextTag1=="SKIN"', 'skin:Skin'),
        hex.case('vers.vers>800 and nextTag1=="SKIN"', 'nextTag2:c4'), -- "UVAS"/"TANG"/"SKIN"
        hex.case('vers.vers>800 and nextTag2=="TANG"', 'tangents:Tangents'),
        hex.case('vers.vers>800 and nextTag2=="TANG"', 'nextTag2:c4'),
        hex.case('vers.vers>800 and nextTag2=="SKIN"', 'skin:Skin'),
        hex.case('vers.vers>800 and nextTag2=="SKIN"', 'nextTag2:c4'), -- "UVAS"
        "textureCoordinateSetsCount:L",
        "textureCoordinateSets:TextureCoordinateSet[textureCoordinateSetsCount]"
    },
    Tangents = {"count:L", "tangents:Vector4[count]"},
    Skin = {"count:L", "skin:uint8[count]"},
    TextureCoordinateSet = {
        ":c4", "count:L", "texutreCoordinates:Vector2[count]"
    },
    TracksChunk = {
        "tag:c4", "tracksCount:L", "interpolationType:L", "globalSequenceId:L",
        "tracks:Track[tracksCount]"

    },
    GeosetAnimation = {
        "inclusiveSize:L", "alpha:f", "flags:L", "color:Color", "geosetId:L",
        "tracks:TracksChunk[?inclusiveSize-4*7]"
    },
    Bone = {"node:Node", "geosetId:L", "geosetAnimationId:L"},
    Light = {
        "inclusiveSize:L", "node:Node", "type:L", "attenuationStart:f",
        "attenuationEnd:f", "color:Color", "intensity:f", "ambientColor:Color",
        "ambientIntensity:f",
        "tracks:TracksChunk[?inclusiveSize-4*12-node.inclusiveSize]"
    },
    Helper = {"node:Node"},
    Attachment = {
        "inclusiveSize:L", "node:Node", "path:c260", "attachmentId:L",
        "tracks:TracksChunk[?inclusiveSize-4*2-260-node.inclusiveSize]"
    },
    ParticleEmitter = {
        "inclusiveSize:L", "node:Node", "emissionRate:f", "gravity:f",
        "longitude:f", "latitude:f", "spawnModelFileName:c260", "lifespan:f",
        "initialiVelocity:f",
        "tracks:TracksChunk[?inclusiveSize-4*7-node.inclusiveSize-260]"
    },
    ParticleEmitter2 = {
        "inclusiveSize:L", "node:Node", "speed:f", "variation:f", "latitude:f",
        "gravity:f", "lifespan:f", "emissionRate:f", "length:f", "width:f",
        "filterMode:L", "rows:L", "columns:L", "headOrTail:L", "tailLength:f",
        "time:f", "segmentColor:Color[3]", "segmentAlpha:uint8[3]",
        "segmentScaling:Vector3", "headInterval:uint32[3]",
        "headDecayInterval:uint32[3]", "tailInterval:uint32[3]",
        "tailDecayInterval:uint32[3]", "textureId:L", "squirt:L",
        "priorityPlane:L", "replaceableId:L",
        "tracks:TracksChunk[?inclusiveSize-4*19-3*12-3-12-9*4-node.inclusiveSize]"
    },
    RibbonEmitter = {
        "inclusiveSize:L", "node:Node", "heightAbove:f", "heightBelow:f",
        "alpha:f", "color:Color", "lifespan:f", "textureSlot:L",
        "emissionRate:L", "rows:L", "columns:L", "materialId:L", "gravity:f",
        "tracks:TracksChunk[?inclusiveSize-4*14-node.inclusiveSize]"
    },
    EventObject = {
        "node:Node", ":c4", "tracksCount:L", "globalSequenceId:L",
        "tracks:uint32[tracksCount]"
    },
    Camera = {
        "inclusiveSize:L", "name:c80", "position:Vector3", "filedOfView:f",
        "farClippingPlane:f", "nearClippingPlane:f", "targetPosition:Vector3",
        "tracks:TracksChunk[?inclusiveSize-4*10-80]"
    },
    CollisionShape = {
        "node:Node", "type:L", hex.case('type == 0', 'vertices:Vector3[2]'),
        hex.case('type == 1', 'vertices:Vector3[2]'),
        hex.case('type == 2', 'vertices:Vector3[1]'),
        hex.case('type == 3', 'vertices:Vector3[2]'),
        hex.case('type == 2', 'radius:f'), hex.case('type == 3', 'radius:f')
    },
    CornEmitter = {
        "inclusiveSize:L", "node:Node", "lifeSpan:f", "emissionRate:f",
        "speed:f", "color:ColorA", "replaceableId:L", "path:c260", "flags:c260",
        "tracks:TracksChunk[?inclusiveSize-4*9-260-260]"
    },

    Track = {
        "frame:l", -- // Node
        hex.case('tag == "KGTR"', 'value:Vector3'), -- translation
        hex.case('interpolationType > 1 and tag == "KGTR"', 'inTan:Vector3'),
        hex.case('interpolationType > 1 and tag == "KGTR"', 'outTan:Vector3'),
        hex.case('tag == "KGRT"', 'value:Vector4'), -- rotation
        hex.case('interpolationType > 1 and tag == "KGRT"', 'inTan:Vector4'),
        hex.case('interpolationType > 1 and tag == "KGRT"', 'outTan:Vector4'),
        hex.case('tag == "KGSC"', 'value:Vector3'), -- scaling
        hex.case('interpolationType > 1 and tag == "KGSC"', 'inTan:Vector3'),
        hex.case('interpolationType > 1 and tag == "KGSC"', 'outTan:Vector3'),
        -- // Layer
        hex.case('tag == "KMTF"', 'value:L'), -- textureId
        hex.case('interpolationType > 1 and tag == "KMTF"', 'inTan:L'),
        hex.case('interpolationType > 1 and tag == "KMTF"', 'outTan:L'),
        hex.case('tag == "KMTA"', 'value:f'), -- alpha
        hex.case('interpolationType > 1 and tag == "KMTA"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KMTA"', 'outTan:f'),
        hex.case('tag == "KMTE"', 'value:f'), -- emissiveGain
        hex.case('interpolationType > 1 and tag == "KMTE"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KMTE"', 'outTan:f'),
        hex.case('tag == "KFC3"', 'value:Color'), -- fresnelColor
        hex.case('interpolationType > 1 and tag == "KFC3"', 'inTan:Color'),
        hex.case('interpolationType > 1 and tag == "KFC3"', 'outTan:Color'),
        hex.case('tag == "KFCA"', 'value:f'), -- fresnelAlpha
        hex.case('interpolationType > 1 and tag == "KFCA"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KFCA"', 'outTan:f'),
        hex.case('tag == "KFTC"', 'value:f'), -- fresnelTeamColor
        hex.case('interpolationType > 1 and tag == "KFTC"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KFTC"', 'outTan:f'),
        -- // Texture animation
        hex.case('tag == "KTAT"', 'value:Vector3'), -- translation
        hex.case('interpolationType > 1 and tag == "KTAT"', 'inTan:Vector3'),
        hex.case('interpolationType > 1 and tag == "KTAT"', 'outTan:Vector3'),
        hex.case('tag == "KTAR"', 'value:Vector4'), -- rotation
        hex.case('interpolationType > 1 and tag == "KTAR"', 'inTan:Vector4'),
        hex.case('interpolationType > 1 and tag == "KTAR"', 'outTan:Vector4'),
        hex.case('tag == "KTAS"', 'value:Vector3'), -- scaling
        hex.case('interpolationType > 1 and tag == "KTAS"', 'inTan:Vector3'),
        hex.case('interpolationType > 1 and tag == "KTAS"', 'outTan:Vector3'),
        -- //Geoset animation
        hex.case('tag == "KGAO"', 'value:f'), -- alpha
        hex.case('interpolationType > 1 and tag == "KGAO"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KGAO"', 'outTan:f'),
        hex.case('tag == "KGAC"', 'value:Color'), -- color
        hex.case('interpolationType > 1 and tag == "KGAC"', 'inTan:Color'),
        hex.case('interpolationType > 1 and tag == "KGAC"', 'outTan:Color'),
        -- // Light
        hex.case('tag == "KLAS"', 'value:f'), -- attenuationStart
        hex.case('interpolationType > 1 and tag == "KLAS"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KLAS"', 'outTan:f'),
        hex.case('tag == "KLAE"', 'value:f'), -- attenuationStartEnd
        hex.case('interpolationType > 1 and tag == "KLAE"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KLAE"', 'outTan:f'),
        hex.case('tag == "KLAC"', 'value:Color'), -- color
        hex.case('interpolationType > 1 and tag == "KLAC"', 'inTan:Color'),
        hex.case('interpolationType > 1 and tag == "KLAC"', 'outTan:Color'),
        hex.case('tag == "KLAI"', 'value:f'), -- intensity
        hex.case('interpolationType > 1 and tag == "KLAI"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KLAI"', 'outTan:f'),
        hex.case('tag == "KLBI"', 'value:f'), -- ambientIntensity
        hex.case('interpolationType > 1 and tag == "KLBI"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KLBI"', 'outTan:f'),
        hex.case('tag == "KLBC"', 'value:Color'), -- ambientColor
        hex.case('interpolationType > 1 and tag == "KLBC"', 'inTan:Color'),
        hex.case('interpolationType > 1 and tag == "KLBC"', 'outTan:Color'),
        hex.case('tag == "KLAV"', 'value:f'), -- visibility
        hex.case('interpolationType > 1 and tag == "KLAV"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KLAV"', 'outTan:f'),
        -- // Attachment
        hex.case('tag == "KATV"', 'value:f'), -- visibility
        hex.case('interpolationType > 1 and tag == "KATV"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KATV"', 'outTan:f'),
        -- // Particle emitter
        hex.case('tag == "KPEE"', 'value:f'), -- emissionRate
        hex.case('interpolationType > 1 and tag == "KPEE"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPEE"', 'outTan:f'),
        hex.case('tag == "KPEG"', 'value:f'), -- gravity
        hex.case('interpolationType > 1 and tag == "KPEG"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPEG"', 'outTan:f'),
        hex.case('tag == "KPLN"', 'value:f'), -- longitude
        hex.case('interpolationType > 1 and tag == "KPLN"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPLN"', 'outTan:f'),
        hex.case('tag == "KPLT"', 'value:f'), -- latitude
        hex.case('interpolationType > 1 and tag == "KPLT"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPLT"', 'outTan:f'),
        hex.case('tag == "KPEL"', 'value:f'), -- lifespan
        hex.case('interpolationType > 1 and tag == "KPEL"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPEL"', 'outTan:f'),
        hex.case('tag == "KPES"', 'value:f'), -- speed
        hex.case('interpolationType > 1 and tag == "KPES"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPES"', 'outTan:f'),
        hex.case('tag == "KPEV"', 'value:f'), -- visibility
        hex.case('interpolationType > 1 and tag == "KPEV"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPEV"', 'outTan:f'),
        -- // Particle emitter 2
        hex.case('tag == "KP2E"', 'value:f'), -- emissionRate
        hex.case('interpolationType > 1 and tag == "KP2E"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2E"', 'outTan:f'),
        hex.case('tag == "KP2G"', 'value:f'), -- gravity
        hex.case('interpolationType > 1 and tag == "KP2G"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2G"', 'outTan:f'),
        hex.case('tag == "KP2L"', 'value:f'), -- latitude
        hex.case('interpolationType > 1 and tag == "KP2L"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2L"', 'outTan:f'),
        hex.case('tag == "KP2S"', 'value:f'), -- speed
        hex.case('interpolationType > 1 and tag == "KP2S"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2S"', 'outTan:f'),
        hex.case('tag == "KP2V"', 'value:f'), -- visibility
        hex.case('interpolationType > 1 and tag == "KP2V"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2V"', 'outTan:f'),
        hex.case('tag == "KP2R"', 'value:f'), -- variation
        hex.case('interpolationType > 1 and tag == "KP2R"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2R"', 'outTan:f'),
        hex.case('tag == "KP2N"', 'value:f'), -- length
        hex.case('interpolationType > 1 and tag == "KP2N"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2N"', 'outTan:f'),
        hex.case('tag == "KP2W"', 'value:f'), -- width
        hex.case('interpolationType > 1 and tag == "KP2W"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KP2W"', 'outTan:f'),
        -- // Ribbon emitter
        hex.case('tag == "KRVS"', 'value:f'), -- visibility
        hex.case('interpolationType > 1 and tag == "KRVS"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KRVS"', 'outTan:f'),
        hex.case('tag == "KRHA"', 'value:f'), -- heightAbove
        hex.case('interpolationType > 1 and tag == "KRHA"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KRHA"', 'outTan:f'),
        hex.case('tag == "KRHB"', 'value:f'), -- heightBelow
        hex.case('interpolationType > 1 and tag == "KRHB"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KRHB"', 'outTan:f'),
        hex.case('tag == "KRAL"', 'value:f'), -- alpha
        hex.case('interpolationType > 1 and tag == "KRAL"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KRAL"', 'outTan:f'),
        hex.case('tag == "KRCO"', 'value:Color'), -- color
        hex.case('interpolationType > 1 and tag == "KRCO"', 'inTan:Color'),
        hex.case('interpolationType > 1 and tag == "KRCO"', 'outTan:Color'),
        hex.case('tag == "KRTX"', 'value:L'), -- textureSlot
        hex.case('interpolationType > 1 and tag == "KRTX"', 'inTan:L'),
        hex.case('interpolationType > 1 and tag == "KRTX"', 'outTan:L'),
        -- // Camera
        hex.case('tag == "KCTR"', 'value:Vector3'), -- translation
        hex.case('interpolationType > 1 and tag == "KCTR"', 'inTan:Vector3'),
        hex.case('interpolationType > 1 and tag == "KCTR"', 'outTan:Vector3'),
        hex.case('tag == "KCRL"', 'value:f'), -- rotation
        hex.case('interpolationType > 1 and tag == "KCRL"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KCRL"', 'outTan:f'),
        hex.case('tag == "KTTR"', 'value:Vector3'), -- targetTranslation
        hex.case('interpolationType > 1 and tag == "KTTR"', 'inTan:Vector3'),
        hex.case('interpolationType > 1 and tag == "KTTR"', 'outTan:Vector3'),
        -- // Corn emitter
        hex.case('tag == "KPPA"', 'value:f'), -- alpha
        hex.case('interpolationType > 1 and tag == "KPPA"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPPA"', 'outTan:f'),
        hex.case('tag == "KPPC"', 'value:Color'), -- color
        hex.case('interpolationType > 1 and tag == "KPPC"', 'inTan:Color'),
        hex.case('interpolationType > 1 and tag == "KPPC"', 'outTan:Color'),
        hex.case('tag == "KPPE"', 'value:f'), -- emissionRate
        hex.case('interpolationType > 1 and tag == "KPPE"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPPE"', 'outTan:f'),
        hex.case('tag == "KPPL"', 'value:f'), -- lifespan
        hex.case('interpolationType > 1 and tag == "KPPL"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPPL"', 'outTan:f'),
        hex.case('tag == "KPPS"', 'value:f'), -- speed
        hex.case('interpolationType > 1 and tag == "KPPS"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPPS"', 'outTan:f'),
        hex.case('tag == "KPPV"', 'value:f'), -- visibility
        hex.case('interpolationType > 1 and tag == "KPPV"', 'inTan:f'),
        hex.case('interpolationType > 1 and tag == "KPPV"', 'outTan:f')
    },
    Node = {
        "inclusiveSize:L", "name:c80", "objectId:L", "parentId:L", "flags:L",
        "tracks:TracksChunk[?inclusiveSize-4*4-80]"
    }

}

local function enableTracy()
    require 'luatracy'

    util.enableCloseFunction()

    local function getGlobal(name)
        local g = _G
        for n in name:gmatch '[^%.]+' do
            g = g[n]
        end
        return g
    end

    local function setGlobal(name, v)
        local g = _G
        local l = {}
        for n in name:gmatch '[^%.]+' do
            l[#l+1] = n
        end
        for i = 1, #l - 1 do
            g = g[l[i]]
        end
        g[l[#l]] = v
    end

    for _, name in ipairs {
        'setmetatable',
        'load',
        'assert',
        'string.pack',
        'string.unpack',
        'string.packsize',
        'string.rep',
    } do

        local origin = getGlobal(name)
        setGlobal(name, function (...)
            tracy.ZoneBeginN(name)
            local a, b, c, d, e, f = origin(...)
            tracy.ZoneEnd()
            return a, b, c, d, e, f
        end)
    end
end

enableTracy()

local mdx = util.loadFile('test/input/mz.mdx')
print('decode #1', os.clock())
local t = mdxparser:decode(mdx)
print('decode #2', os.clock())
fs.create_directories(fs.path 'test/output')

local mzLua = util.dump(t)
util.saveFile('test/output/mz.lua', mzLua)
assert(mzLua == util.loadFile('test/input/mz.lua'))
