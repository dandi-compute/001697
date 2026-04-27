# 🧠 Dandiset 001697

> A copy of the Dandiset, updated more regularly than its corresponding [DataLad dataset](https://github.com/dandisets/001697).

---

## 🗂️ Layout

The outer level of the Dandiset is organized according to a [BIDS-Study](https://bids-specification.readthedocs.io/en/stable/common-principles.html#study-dataset) layout.

The primary `derivatives/` directory follows the [Type 1 BIDS-Derivatives](https://bids-specification.readthedocs.io/en/stable/common-principles.html#storage-of-derived-datasets) structure.

The nesting pattern follows the specific structure:

```
001697/
└── derivatives/
    └── dandiset-{Dandiset ID}/
    │   └── sub-{subject ID}/
    │       └── [ses-{session ID}/]  ← optional
    │           └── pipeline-{pipeline ID}/
    │               └── version-{version ID}/
    │                   └── [params-{hash}_config-{hash}_attempt-{counter}/]
    │                       ├── code/  ← a copy of the exact code used to run the pipeline
    │                       ├── logs/  ← all runtime records for success or failure
    │                       ├── output/  ← the spike sorting output
    │                       ├── visualizations/  ← associated figures for intermediate processing
    │                       └── dataset_description.json  ← provenance info
    └── dandiset-.../
```


Each subdirectory at the bottom level is itself a **self-contained BIDS-Study**, with the `dataset_description.json` containing provenance information about the pipeline and submission software versions used to generate that dataset.



### Setting up `git-annex` on MIT Engaging

```
dandi_instance: dandi
s3bucket: dandiarchive
backup_root: /path/to/backups
dandisets:
  path: dandisets
  github_org: dandisets        # GitHub org where repos will be created
  remote:
    name: dandi-backup
    type: s3
    options:
      bucket: my-backup-bucket
zarrs:
  path: zarrs
  github_org: dandizarrs
  remote:
    name: dandi-zarr-backup
    type: s3
    options:
      bucket: my-zarr-bucket
jobs: 4
workers: 4
```

```
cd /orcd/data/dandi/001/dandi-compute
backups2datalad -B ./datalad -c config.yaml update-from-backup 001697
backups2datalad -B ./datalad -c config.yaml populate 001697
```
