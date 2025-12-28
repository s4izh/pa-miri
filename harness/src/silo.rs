use std::path::{Path, PathBuf};

pub struct SiloResolver {
    pub root: PathBuf,
}

impl SiloResolver {
    pub fn new(root: PathBuf) -> Self {
        Self { root }
    }

    /// HW: build/hw/<processor>/<variant>/<testbench>/<simulator>/
    pub fn hw_dir(&self, proc: &str, variant: &str, tb: &str, sim: &str) -> PathBuf {
        self.root
            .join("hw")
            .join(proc)
            .join(variant)
            .join(tb)
            .join(sim)
    }

    /// SW: build/sw/<suite>/<rel_path_to_prog>/
    pub fn sw_dir(&self, suite: &str, rel_path: &Path) -> PathBuf {
        self.root.join("sw").join(suite).join(rel_path)
    }

    /// SIM: build/sim/<binding>/<proc>_<var>/<tb>/<sim>/<suite>/<prog_path>/
    pub fn sim_dir(
        &self,
        binding: &str,
        proc: &str,
        variant: &str,
        tb: &str,
        sim: &str,
        suite: &str,
        rel_path: &Path,
    ) -> PathBuf {
        self.root
            .join("sim")
            .join(binding)
            .join(format!("{}_{}", proc, variant))
            .join(tb)
            .join(sim)
            .join(suite)
            .join(rel_path)
    }
}
