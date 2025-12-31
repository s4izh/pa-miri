use std::path::Path;
use walkdir::WalkDir;

pub fn discover_unit_tests(root: &Path) -> Vec<StandaloneExperiment> {
    let unit_tb_dir = root.join("tb/common");
    let mut tests = Vec::new();

    if !unit_tb_dir.exists() {
        return tests;
    }

    for entry in WalkDir::new(unit_tb_dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();
        if path.extension().map_or(false, |ext| ext == "f") {
            let name = path.file_stem().unwrap().to_string_lossy().to_string();
            
            println!("adding {name} as unit test");
            
            tests.push(StandaloneExperiment {
                name,
                filelist: path.to_path_buf(),
                simulator: "verilator".into(), // Default simulator
                plusargs: vec!["+TIMEOUT_CYCLES=5000".into()],
            });
        }
    }
    tests
}
