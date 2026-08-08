export interface ReferenceRepo {
  readonly id: string;
  readonly prefix: string;
  readonly repository: string;
  readonly latestRef: string;
  readonly versionSourcePath: string;
  readonly packageVersionPath: ReadonlyArray<string>;
  readonly versionTagPrefix: string;
}

export const referenceRepos: ReadonlyArray<ReferenceRepo> = [
  {
    id: "beetle-vb-libretro",
    prefix: ".repos/beetle-vb-libretro",
    repository: "https://github.com/libretro/beetle-vb-libretro.git",
    latestRef: "master",
    versionSourcePath: ".repos/versions.json",
    packageVersionPath: ["beetle-vb-libretro"],
    versionTagPrefix: "",
  },
  {
    id: "mednafen-git",
    prefix: ".repos/mednafen-git",
    repository: "https://github.com/libretro-mirrors/mednafen-git.git",
    latestRef: "master",
    versionSourcePath: ".repos/versions.json",
    packageVersionPath: ["mednafen-git"],
    versionTagPrefix: "",
  },
  {
    id: "vuengine-studio",
    prefix: ".repos/vuengine-studio",
    repository: "https://github.com/VUEngine/VUEngine-Studio.git",
    latestRef: "master",
    versionSourcePath: ".repos/versions.json",
    packageVersionPath: ["vuengine-studio"],
    versionTagPrefix: "",
  },
];
