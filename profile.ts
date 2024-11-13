const zig = require('./zig-out/lib/node-zig.node');

const timeRms = (name, rms, values) => {
    const start = performance.now();

    for (let i = 0; i < 1_000_000; i++) {
        rms(values);
    }

    const end = performance.now();

    console.log(`${name}: ${end - start}`);
}

const basicRms = values => {
    Math.sqrt((values.map(v => v * v).reduce((acc, cur) => acc + cur) / values.len))
};

const vals = new Float32Array(new Array(100).fill(1).map(() => Math.random()));
timeRms("micRms", zig.micRms, vals);
timeRms("rms", zig.rms, vals);
timeRms("basicRms", basicRms, vals);