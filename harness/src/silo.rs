use std::path::PathBuf;
use crate::core::Job;

pub struct SiloResolver {
    pub root: PathBuf,
}

impl SiloResolver {
    pub fn new() -> Self {
        Self { root: PathBuf::from("build_silo") }
    }

    /// HW: build_silo/hw/<gen>/<var>/<tb>/<sim>/
    pub fn hw_dir(&self, j: &Job) -> PathBuf {
        self.root.join("hw").join(&j.generator.name).join(&j.variant_name).join(&j.tb.name).join(&j.sim.name)
    }

    pub fn hw_bin(&self, j: &Job) -> PathBuf {
        self.hw_dir(j).join("Vtop")
    }

    /// SW: build_silo/sw/<suite>/<rel_dir>/<prog>/
    pub fn sw_dir(&self, j: &Job) -> PathBuf {
        self.root.join("sw").join(&j.program.suite_name).join(&j.program.rel_dir).join(&j.program.name)
    }

    /// SIM: build_silo/sim/<gen>/<var>/<tb>/<sim>/<suite>/<rel_dir>/<prog>/
    pub fn sim_dir(&self, j: &Job) -> PathBuf {
        self.root.join("sim")
            .join(&j.generator.name).join(&j.variant_name).join(&j.tb.name).join(&j.sim.name)
            .join(&j.program.suite_name).join(&j.program.rel_dir).join(&j.program.name)
    }
}
