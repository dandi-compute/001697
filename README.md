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



### Setting up DataLad/`git-annex` on MIT Engaging

```
dandi_instance: dandi
s3bucket: dandiarchive
backup_root: /orcd/data/dandi/001/dandi-compute/datalad
dandisets:
  path: dandisets
  github_org: dandi-compute        # GitHub org where repos will be created
zarrs:
  path: zarrs
  github_org: dandi-compute
jobs: 1
workers: 1
```

Then refer to [submitter/sync-datalad.yml](https://github.com/dandi-compute/submitter/blob/main/.github/workflows/sync-datalad.yml) for details on how `backups2datalad` is run.

After the first run, we decided to host PNG files via the GitHub CDN for the webpage.
This requires unannexing these files:

```
cat >> .gitattributes << 'EOF'
*.png annex.largefiles=nothing
EOF

find . -name '*.png' -exec git annex unannex {} +

git add .gitattributes
git add '*.png'
git commit -m "Track PNGs in Git directly instead of git-annex"
```
