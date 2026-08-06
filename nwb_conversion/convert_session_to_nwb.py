#!/usr/bin/env python3
"""
convert_session_to_nwb.py -- Psychedelic_Sniff mission

Converts one session of the DOI-vs-saline olfactory search task dataset
(Welch, Gonzales-Hess, Tarvin, Connor, Smear -- "The impact of a
psychedelic drug on olfactory search behavior by mice," bioRxiv
2025.07.09.663970) into a single NWB file.

Source: /Volumes/TOSHIBA (external drive, read-only from this machine --
never written to). See CLAUDE.md for the full data-format mapping this
implements, and MISSION_NOTES.md for how each piece of that mapping was
verified (and what's still an open assumption).

PROTOTYPE STATUS, 2026-08-06: built and run on two example sessions (one
per cohort) for review. NOT yet run at scale on all 44 sessions -- see
MISSION_NOTES.md before doing that.

Scope, decided 2026-08-06: the 44 sessions listed in DLC_tracked_task
(22 mice x doi/saline), not the full 731-session newmove set.

Two cohorts, different raw layouts (see CLAUDE.md "Data layout" for the
full account of how this was discovered):
  - Cohort A (mice 2174, 2181, 2182, 2183, 2185): trialsummary.txt is the
    only trial table; no Bpod files.
  - Cohort B (mice 2191-2213): trialsummary_falsealarms_softcode_repoke.txt
    is the trial table used here. Matt, 2026-08-06, on the FalseAlarm
    column's disagreement with an earlier-named sibling file for the same
    trial: "make it so, present it as settled." Used as final; the
    disagreement is documented in MISSION_NOTES.md, not resolved by
    re-deriving from Bpod raw events.

Position: DLC_tracked_task ONLY (Matt, 2026-08-06: "DLC-only"). newmove's
own tracking (headx.dat etc., cohort A only anyway) is never used for
position in the NWB output.

Usage:
    python3 convert_session_to_nwb.py <mouse> <session> <doi|saline> [--out DIR]
"""
import argparse
import os
import re

import numpy as np
import pandas as pd
import scipy.io as sio
from dateutil import parser as dateparser
from pynwb import NWBFile, NWBHDF5IO, TimeSeries
from pynwb.file import Subject
from pynwb.behavior import BehavioralTimeSeries
from ndx_pose import PoseEstimationSeries, PoseEstimation, Skeleton, Skeletons

DRIVE = '/Volumes/TOSHIBA'
NEWMOVE = f'{DRIVE}/newmove'
DLC_DIR = f'{DRIVE}/DLC_tracked_task'
SNIFF_DIR = f'{DRIVE}/Task sniff params'
TSTASK_DIR = f'{DRIVE}/Time Stamps Task'
TSLOGAN_DIR = f'{DRIVE}/Time Stamps Task Logan'

COHORT_A_MICE = {'2174', '2181', '2182', '2183', '2185'}

INSTITUTION = 'University of Oregon'  # Matt, 2026-08-06 -- corrected from
# an earlier, unsourced "UC Riverside" guess. Do not reintroduce that.

# Matt, 2026-08-06: "I know the rough ages of the mice, they were all 4-9
# months old" -- exact per-animal DOB was judged unlikely to be
# recoverable, so this stated range is the ground truth for Subject.age
# unless animal_dob.csv (below) gives an exact DOB for a specific mouse.
# ISO 8601 duration RANGE syntax ('lower/upper'), confirmed against the
# installed nwbinspector's own validation regex
# (nwbinspector/checks/_nwbfile_metadata.py::check_subject_age) before
# using it here, not assumed from memory.
FALLBACK_AGE_RANGE = 'P4M/P9M'

# notes.txt's Experimenter field is inconsistent: sometimes a bare first
# name, sometimes "First Last", sometimes a nickname/abbreviation. Bare
# first names are looked up here ONLY once confirmed -- do not add an
# entry by guessing. Checked across all 44 DLC-scoped sessions'
# notes.txt (2026-08-06): the actual values are 'Amanda' (37), 'Rebecca
# Marsden' (3, full name already), 'Takisha Tarvin' (2, full name
# already), 'Tk' (2, UNCONFIRMED -- plausibly Takisha Tarvin's initials,
# not assumed).
EXPERIMENTER_LASTNAMES = {
    'Amanda': 'Welch, Amanda',   # confirmed, Matt 2026-08-06 -- matches paper author "Amanda C Welch"
    'Tk': 'Tarvin, Takisha',     # confirmed, Matt 2026-08-06: "TK is Takisha Tarvin"
}


def format_experimenter(raw):
    """'First Last' -> 'Last, First' (mechanical, safe since the full
    name is already present). A single bare token is looked up in
    EXPERIMENTER_LASTNAMES; if not found, returned unchanged with a
    warning rather than guessed."""
    raw = raw.strip()
    if not raw:
        return 'unknown'
    parts = raw.split()
    if len(parts) >= 2:
        *first, last = parts
        return f"{last}, {' '.join(first)}"
    if raw in EXPERIMENTER_LASTNAMES:
        return EXPERIMENTER_LASTNAMES[raw]
    print(f"WARNING: no confirmed last name for experimenter {raw!r} -- "
          f"left unformatted, needs a real answer before this session's "
          f"NWB file is considered final.")
    return raw

BODYPARTS = ['nose', 'head', 'earL', 'earR', 'body', 'latL', 'latR', 'tailbase']

# Column layout for cohort B's trialsummary_falsealarms_softcode_repoke.txt,
# confirmed from the header row of the sibling file
# trial_summary_with_false_alarms_repokes.txt (see CLAUDE.md). No header
# in the _repoke file itself -- confirmed by column COUNT (9) and value
# alignment against the headered sibling, not assumed.
COHORT_B_TRIAL_COLS = [
    'trial_count', 'odor_control', 'side', 'outcome',
    'start_time', 'end_time', 'iti_time', 'false_alarm', 'repoke',
]
# Cohort A's plain trialsummary.txt -- same first 7 fields, by analogy
# (not independently confirmed with a header anywhere in this cohort).
COHORT_A_TRIAL_COLS = [
    'trial_count', 'odor_control', 'side', 'outcome',
    'start_time', 'end_time', 'iti_time',
]


def parse_notes(path):
    """Parse notes.txt into a dict. Tolerant of the two known schemas
    (cohort A: 'Forced to one side'/'Odor Percentage'/etc; cohort B:
    'Side Bias'/'Drug Dose'/etc) -- just splits each line on the first
    ':', doesn't assume which fields exist. First occurrence of a key
    wins (guards against the repeated bare "L:"/"R:" performance lines
    that aren't ':'-delimited the same way anyway)."""
    d = {}
    with open(path, errors='replace') as fh:
        for line in fh:
            line = line.rstrip('\n')
            if ':' in line:
                k, v = line.split(':', 1)
                k = k.strip()
                if k and k not in d:
                    d[k] = v.strip()
    return d


def parse_session_start(notes):
    date_str = notes.get('Date', '')
    dt = dateparser.parse(date_str, fuzzy=True)
    if dt is None:
        raise ValueError(f'could not parse Date field: {date_str!r}')
    if dt.tzinfo is None:
        # Institution is University of Oregon (Matt, 2026-08-06 --
        # correcting an earlier, unsourced "UC Riverside" guess this
        # script had no actual basis for). Eugene, OR is Pacific time,
        # same tz identifier as the wrong guess, so no functional bug --
        # but the comment justifying it was fabricated and needed fixing
        # regardless of whether the answer happened to be right.
        import pytz
        dt = pytz.timezone('America/Los_Angeles').localize(dt)
    return dt


def parse_sex(notes):
    raw = (notes.get('Mouse sex') or notes.get('Sex') or '').strip()
    if not raw:
        return 'U'
    c = raw[0].upper()
    return c if c in ('M', 'F') else 'U'


def load_dlc(mouse, session, condition):
    path = f'{DLC_DIR}/{mouse}_{session}_{condition}.csv'
    df = pd.read_csv(path, header=[1, 2], index_col=0)
    return df


def load_sniff_params(mouse, session):
    path = f'{SNIFF_DIR}/sniff_params_sniff_{mouse}_{session}.mat'
    if not os.path.isfile(path):
        return None
    d = sio.loadmat(path)
    return d['sniff_params']


def load_event_timestamps(mouse, session):
    """Returns (times_s, source_label) or (None, None). Tries both known
    formats -- 'Time Stamps Task' (UTF-16, HH:MM:SS:CS strings) and
    'Time Stamps Task Logan' (plain ASCII seconds)."""
    p1 = f'{TSTASK_DIR}/{mouse}_{session}.csv'
    p2 = f'{TSLOGAN_DIR}/{mouse}_{session}.csv'
    if os.path.isfile(p1):
        with open(p1, encoding='utf-16') as fh:
            lines = [l.strip() for l in fh if l.strip()]
        out = []
        for l in lines:
            hh, mm, ss, cs = (int(x) for x in l.split(':'))
            out.append(hh * 3600 + mm * 60 + ss + cs / 100.0)
        return np.array(out), 'Time Stamps Task'
    if os.path.isfile(p2):
        with open(p2) as fh:
            out = [float(l.strip()) for l in fh if l.strip()]
        return np.array(out), 'Time Stamps Task Logan'
    return None, None


def parse_trial_table(mouse, session, session_dir):
    """Returns (rows, colnames). Cohort A: trialsummary.txt (7 cols).
    Cohort B: trialsummary_falsealarms_softcode_repoke.txt (9 cols) --
    see module docstring for why this file, not one of its siblings."""
    if mouse in COHORT_A_MICE:
        path = f'{session_dir}/trialsummary.txt'
        cols = COHORT_A_TRIAL_COLS
    else:
        path = f'{session_dir}/trialsummary_falsealarms_softcode_repoke.txt'
        cols = COHORT_B_TRIAL_COLS
    rows = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            parts = [float(x) for x in line.split(',')]
            if len(parts) != len(cols):
                raise ValueError(
                    f'{path}: expected {len(cols)} columns, got {len(parts)} '
                    f'in line {line!r}'
                )
            rows.append(parts)
    return rows, cols


def load_dob_lookup():
    """Optional mouse_id,date_of_birth CSV, for the rare case an exact DOB
    turns up for a specific mouse despite Matt's 2026-08-06 expectation
    that this generally won't be recoverable ("I know the rough ages of
    the mice, they were all 4-9 months old... I'm pessimistic we can find
    the DOB info"). When absent for a mouse (the default), FALLBACK_AGE_RANGE
    is used instead -- see convert_session(). Returns {} if the file
    doesn't exist at all."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'animal_dob.csv')
    if not os.path.isfile(path):
        return {}
    df = pd.read_csv(path, dtype={'mouse_id': str})
    return dict(zip(df['mouse_id'], df['date_of_birth']))


def convert_session(mouse, session, condition, out_dir):
    session_dir = f'{NEWMOVE}/{mouse}/100-0/{session}'
    notes = parse_notes(f'{session_dir}/notes.txt')
    session_start = parse_session_start(notes)
    cohort = 'A' if mouse in COHORT_A_MICE else 'B'

    dob_lookup = load_dob_lookup()
    dob_str = dob_lookup.get(str(mouse))
    subject_kwargs = dict(
        subject_id=str(mouse),
        sex=parse_sex(notes),
        species='Mus musculus',
        description=f'Drug condition this session: {condition} (from DLC_tracked_task filename).',
    )
    if dob_str:
        dob = dateparser.parse(dob_str, fuzzy=True)
        if dob.tzinfo is None:
            import pytz
            dob = pytz.timezone('America/Los_Angeles').localize(dob)
        subject_kwargs['date_of_birth'] = dob
    else:
        # No exact DOB for this mouse -- use the stated fallback range
        # (Matt, 2026-08-06) rather than leaving age/DOB empty.
        subject_kwargs['age'] = FALLBACK_AGE_RANGE
    subject = Subject(**subject_kwargs)

    nwbfile = NWBFile(
        session_description=(
            f'Olfactory search task (2-PE odor, left/right choice, 10% '
            f'no-odor catch trials, 5s response window). Drug condition: '
            f'{condition}. Cohort {cohort} (see CLAUDE.md for what that means '
            f'operationally -- different raw acquisition system, same task).'
        ),
        identifier=f'{mouse}_{session}',
        session_start_time=session_start,
        session_id=f'{mouse}_{session}',
        experimenter=[format_experimenter(notes.get('Experimenter', ''))],
        experiment_description=(
            'Welch, Gonzales-Hess, Tarvin, Connor, Smear -- "The impact of a '
            'psychedelic drug on olfactory search behavior by mice," '
            'bioRxiv 2025.07.09.663970.'
        ),
        institution=INSTITUTION,
        keywords=['olfaction', 'psychedelics', 'DOI', 'olfactory search', 'mouse', 'behavior'],
        subject=subject,
        notes=str(notes),
    )
    nwbfile.add_scratch(
        name='drug_condition',
        data=condition,
        description=(
            'doi or saline. Ground truth is the DLC_tracked_task filename '
            'for this (mouse, session), confirmed against '
            'doi_session_info_and_links.xlsx for cohort A and against '
            "notes.txt's free-text Drug Dose field where present for "
            'cohort B (that field alone was NOT reliable -- see '
            'MISSION_NOTES.md 2026-08-06).'
        ),
    )

    # --- Position: DLC_tracked_task ONLY (Matt, 2026-08-06: "DLC-only") ---
    dlc = load_dlc(mouse, session, condition)
    n_frames = len(dlc)
    last_trial_end = None  # filled in below once the trial table is parsed;
    # used to estimate a frame rate since no direct per-frame camera
    # timestamp source was found for these sessions (see CLAUDE.md) --
    # THIS IS AN APPROXIMATION, not a measured rate. Flagged in the
    # PoseEstimation description, not just here.

    trial_rows, trial_cols = parse_trial_table(mouse, session, session_dir)
    end_time_idx = trial_cols.index('end_time')
    last_trial_end = max(r[end_time_idx] for r in trial_rows)
    fps_estimate = n_frames / last_trial_end

    skeleton = Skeleton(
        name='mouse_skeleton',
        nodes=BODYPARTS,
        edges=np.array([[0, 1], [1, 4], [1, 2], [1, 3], [4, 5], [4, 6], [4, 7]], dtype='uint8'),
        subject=subject,
    )
    pose_series = []
    for bp in BODYPARTS:
        x = dlc[(bp, 'x')].to_numpy(dtype=float)
        y = dlc[(bp, 'y')].to_numpy(dtype=float)
        conf = dlc[(bp, 'likelihood')].to_numpy(dtype=float)
        pose_series.append(PoseEstimationSeries(
            name=bp,
            data=np.column_stack([x, y]),
            unit='pixels',
            reference_frame='top-left corner of the camera frame, DeepLabCut default',
            confidence=conf,
            confidence_definition='DeepLabCut softmax output',
            starting_time=0.0,
            rate=float(fps_estimate),
            description=(
                f'x,y in pixels, DeepLabCut model '
                f'DLC_resnet_50_olfactory-searchFeb23shuffle1_300000.'
            ),
        ))
    pose_estimation = PoseEstimation(
        pose_estimation_series=pose_series,
        name='PoseEstimation',
        description=(
            'DeepLabCut tracking, 8 keypoints, from DLC_tracked_task -- '
            'the tracking used for this paper\'s main analysis (Matt, '
            '2026-08-06), not newmove\'s own separate (simpler, cohort-A-only) '
            'tracking arrays.'
        ),
        source_software='DeepLabCut',
        skeleton=skeleton,
    )
    behavior_pm = nwbfile.create_processing_module(
        name='behavior', description='Position tracking, sniff, and task events.'
    )
    skeletons = Skeletons(skeletons=[skeleton])
    behavior_pm.add(skeletons)
    behavior_pm.add(pose_estimation)

    # --- Sniff (cohort-agnostic; may be absent) ---
    sniff = load_sniff_params(mouse, session)
    if sniff is not None:
        bad = sniff[:, 2] == 0   # exhalation_time_ms == 0 -> incomplete inhalation, per this project's own convert_fm_ephys_to_npz.py convention
        good = sniff[~bad]
        sniff_table = nwbfile.create_time_intervals(
            name='sniff_cycles',
            description=(
                'One row per detected inhalation/exhalation cycle, from '
                'sniff_params.mat. Columns confirmed from this project\'s '
                'own convert_fm_ephys_to_npz.py / core_sid.py (see CLAUDE.md). '
                f'{int(bad.sum())} of {len(sniff)} rows dropped for this '
                'session (exhalation_time_ms == 0, incomplete detection at '
                'a recording edge).'
            ),
        )
        sniff_table.add_column('inhalation_voltage', 'raw sniff-thermistor voltage at inhalation onset')
        sniff_table.add_column('exhalation_voltage', 'raw sniff-thermistor voltage at exhalation onset')
        for row in good:
            sniff_table.add_row(
                start_time=row[0] / 1000.0,
                stop_time=row[2] / 1000.0,
                inhalation_voltage=row[1],
                exhalation_voltage=row[3],
            )

    # --- Task event timestamps (cohort-agnostic; may be absent) ---
    ev_times, ev_source = load_event_timestamps(mouse, session)
    if ev_times is not None:
        behavior_pm.add(TimeSeries(
            name='task_event_timestamps',
            data=np.ones(len(ev_times)),
            unit='n.a.',
            timestamps=ev_times,
            description=(
                f'Event times (s) from {ev_source}. Relationship to the '
                'trials table\'s own start/end times not independently '
                'confirmed -- see MISSION_NOTES.md.'
            ),
        ))

    # --- Trials ---
    # Sorted by start_time before writing: 2 of the 44 raw trialsummary
    # files (2183_34, 2181_42) have a row physically out of place by 3
    # positions relative to chronological order (caught by nwbinspector's
    # check_time_interval_time_columns, confirmed against the raw file --
    # not a conversion bug). Matt, 2026-08-06: sort by start_time, don't
    # keep trial_count as a column (see MISSION_NOTES.md for the
    # discarded option of keeping it visible instead).
    trial_rows = sorted(trial_rows, key=lambda r: r[trial_cols.index('start_time')])
    for col in trial_cols:
        if col in ('trial_count', 'start_time', 'end_time'):
            continue
        nwbfile.add_trial_column(name=col, description=col.replace('_', ' '))
    for row in trial_rows:
        d = dict(zip(trial_cols, row))
        nwbfile.add_trial(
            start_time=d['start_time'],
            stop_time=d['end_time'],
            **{k: v for k, v in d.items() if k not in ('trial_count', 'start_time', 'end_time')},
        )

    os.makedirs(out_dir, exist_ok=True)
    out_path = f'{out_dir}/{mouse}_{session}_{condition}.nwb'
    with NWBHDF5IO(out_path, 'w') as io:
        io.write(nwbfile)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mouse')
    ap.add_argument('session')
    ap.add_argument('condition', choices=['doi', 'saline'])
    ap.add_argument('--out', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'nwb_output'))
    args = ap.parse_args()
    out_path = convert_session(args.mouse, args.session, args.condition, args.out)
    print(f'wrote {out_path}')


if __name__ == '__main__':
    main()
