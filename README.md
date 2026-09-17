# 🧠 Dandiset 001697

This is a dedicated dataset for DANDI Compute, including the automated spike-sorting outputs from the AIND ephys pipeline.

---

## 🗂️ Layout

The outer level of the Dandiset is organized according to a [Type 1 BIDS-Derivative layout](https://bids-specification.readthedocs.io/en/stable/common-principles.html#storage-of-derived-datasets).

The nesting pattern follows the specific structure:

```
001697/
└── derivatives/
    └── dandisets-{first 3 digits of Dandiset ID}/
        └── dandiset-{Dandiset ID}/
        │       └── sub-{subject ID}/
        │       │   └── [ses-{session ID}/]  ← optional
        │       │   │   └── pipeline-{pipeline ID}/
        │       │   │       └── job-{job ID}/
        │       │   │       │   ├── code/  ← a copy of the exact code used to run the pipeline
        │       │   │       │   ├── logs/  ← all runtime records for success or failure
        │       │   │       │   ├── output/  ← the spike sorting output
        │       │   │       │   ├── visualizations/  ← associated figures for intermediate processing
        │       │   │       │   └── dataset_description.json  ← provenance info
        │       │   │       └── job-.../
        │       │   └── [ses-.../]
        │       └── sub-.../
        └── dandiset-.../
```

Each job capsule is a **self-contained [BIDS-Study](https://bids-specification.readthedocs.io/en/stable/common-principles.html#study-dataset)**, with the `dataset_description.json` containing provenance information about the pipeline and submission software versions used to generate that dataset.
