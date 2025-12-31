use std::path::{Path, PathBuf};

pub struct SiloResolver {
    pub root: PathBuf,
}

impl SiloResolver {
    pub fn new(root: PathBuf) -> Self { Self { root } }

    /// HW: build/hw/<testbench>/<param_set>/<simulator>/
    pub fn hw_dir(&self, tb: &str, ps: &str, sim: &str) -> PathBuf {
        self.root.join("hw").join(tb).join(ps).join(sim)
    }

    pub fn hw_common_dir(&self, tb: &str, ps: &str) -> PathBuf {
        self.root.join("hw").join(tb).join(ps)
    }

    /// SW: build/sw/<suite>/<rel_path>/ (Stays the same)
    pub fn sw_dir(&self, suite: &str, rel_path: &Path) -> PathBuf {
        self.root.join("sw").join(suite).join(rel_path)
    }

    /// SIM: build/sim/<binding>/<tb>/<ps>/<sim>/<suite>/<prog>/
    pub fn sim_dir(
        &self,
        bind_name: &str,
        tb: &str,
        ps: &str,
        sim: &str,
        suite: &str,
        rel_path: &Path,
    ) -> PathBuf {
        self.root
            .join("sim")
            .join(bind_name)
            .join(tb)
            .join(ps)
            .join(sim)
            .join(suite)
            .join(rel_path)
    }
}
