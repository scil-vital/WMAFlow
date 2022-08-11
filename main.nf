#!/usr/bin/env nextflow

if(params.help) {
    usage = file("$baseDir/USAGE")
    cpu_count = Runtime.runtime.availableProcessors()

    bindings = ["cpu_count":"$cpu_count",
                "qc_only_anatomical_tracts":"$params.qc_only_anatomical_tracts"]

    engine = new groovy.text.SimpleTemplateEngine()
    template = engine.createTemplate(usage.text).make(bindings)
    print template.toString()
    return
}

log.info "White Matter Analysis (Spectral Clustering)"
log.info "==============================================="
log.info ""
log.info "Start time: $workflow.start"
log.info ""

log.debug "[Command-line]"
log.debug "$workflow.commandLine"
log.debug ""

log.info "[Git Info]"
log.info "$workflow.repository - $workflow.revision [$workflow.commitId]"
log.info ""

log.info "Options"
log.info "======="
log.info ""
log.info "[Atlas]"
log.info "Atlas Directory: $params.atlas_directory"
log.info ""
log.info "[Slicer]"
log.info "Slicer: $params.slicer_path"
log.info ""
log.info "[QC]"
log.info "QC Only Anatomical Tract: $params.qc_only_anatomical_tracts"
log.info ""

workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    log.info "Execution duration: $workflow.duration"
}

log.info "Input: $params.input"
root = file(params.input)

Channel
    .fromFilePairs("$root/**/*vtk", size: -1) { it.parent.name }
    .into{ 
        sub_for_qc_track; 
        sub_for_qc_overlap;
        sub_for_registration 
    } 

if (!(params.atlas_directory)) {
    error "You must specify --atlas_directory."
}

slicer = Channel.fromPath("$params.slicer_path")

Channel.fromPath("$params.atlas_directory")
    .into{ 
        atlas_directory_qc_overlap; 
        atlas_directory_register;
        atlas_directory_post_registration;
        atlas_directory_for_cluster;
        atlas_directory_for_outliers_removal;
        atlas_directory_for_hemisphere_assessment;
        atlas_directory_for_clusters_to_anatomical_tracts
    }

process WM_Quality_Control_Tractography {
    publishDir "./results/${sid}/QC"
    memory '5 GB'

    input:
    set sid, file(sub) from sub_for_qc_track

    output:
    file "InputTractography/*"

    script:
    """
    mkdir tmp
    mv ${sub} tmp/
    wm_quality_control_tractography.py tmp/ ./InputTractography
    """
}

sub_for_qc_overlap
    .combine(atlas_directory_qc_overlap)
    .set{files_for_wm_quality_control_tract_overlap}

process WM_Quality_Control_Tract_Overlap {
    publishDir "./results/${sid}/QC"
    memory '5 GB'

    input:
    set sid, file(sub), file(atlas_directory) from files_for_wm_quality_control_tract_overlap

    output:
    file "InputTractOverlap/*"

    script:
    String tracking = sub.join(", ").replace(',', '')
    """
    for i in ${tracking}
    do
        filename=\$(basename -- "\$i")
        name="\${filename%.*}"
        wm_quality_control_tract_overlap.py ${atlas_directory}/ORG-800FC-100HCP/atlas.vtp \$i ./InputTractOverlap/\${name}
    done
    """
}

sub_for_registration
    .combine(atlas_directory_register)
    .set{files_for_registration}

process WM_Register_To_Atlas_New {
    publishDir "./results/${sid}/TractRegistration"
    memory '5 GB'

    input:
    set sid, file(sub), file(atlas_directory) from files_for_registration

    output:
    set sid, "*" into tract_registration_for_qc, tract_registration_for_cluster, tract_registration_for_harden_transform

    script:
    String tracking = sub.join(", ").replace(',', '')
    """
    for i in ${tracking}
    do
        filename=\$(basename -- "\$i")
        name="\${filename%.*}"
        wm_register_to_atlas_new.py -mode rigid_affine_fast \$i ${atlas_directory}/ORG-RegAtlas-100HCP/registration_atlas.vtk ./\${name}
    done
    """
}

tract_registration_for_qc
    .combine(atlas_directory_post_registration)
    .set{files_for_wm_quality_control_tract_overlap_post_registration}

process WM_Quality_Control_Tract_Overlap_Post_Registration {
    publishDir "./results/${sid}/QC"
    memory '5 GB'

    input:
    set sid, file(tract_registration), file(atlas_directory) from files_for_wm_quality_control_tract_overlap_post_registration

    output:
    file "RegTractOverlap/*"

    when:
    !params.qc_only_anatomical_tracts

    script:
    String tracking = tract_registration.join(", ").replace(',', '')
    """
    for i in ${tracking}
    do
        name=\$(basename "\$i")
        wm_quality_control_tract_overlap.py ${atlas_directory}/ORG-800FC-100HCP/atlas.vtp \${i}/\${name}/output_tractography/\${name}_reg.vtk ./RegTractOverlap/\${name}
    done
    """
}

tract_registration_for_cluster
    .combine(atlas_directory_for_cluster)
    .set{files_for_wm_cluster_from_atlas}

process WM_Cluster_From_Atlas {
    publishDir "./results/${sid}/FiberClustering"
    memory '5 GB'

    input:
    set sid, file(tract_registration), file(atlas_directory) from files_for_wm_cluster_from_atlas

    output:
    set sid, "InitialClusters/*" into initial_cluster_for_qc, initial_cluster_for_outliers_removal

    script:
    String tracking = tract_registration.join(", ").replace(',', '')
    """
    for i in ${tracking}
    do
        name=\$(basename "\$i")
        wm_cluster_from_atlas.py \${i}/\${name}/output_tractography/\${name}_reg.vtk ${atlas_directory}/ORG-800FC-100HCP/  ./InitialClusters/\${name}
    done
    """
}

process WM_Quality_Control_Tractography_For_Clusters {
    publishDir "./results/${sid}/QC"
    memory '5 GB'

    input:
    set sid, file(clusters) from initial_cluster_for_qc

    output:
    file "FiberCluster-Initial/*"

    when:
    !params.qc_only_anatomical_tracts

    script:
    String clusters = clusters.join(", ").replace(',', '')
    """
    for i in ${clusters}
    do
        name=\$(basename "\$i")
        wm_quality_control_tractography.py \${i}/\${name}_reg/ ./FiberCluster-Initial/\${name}   
    done
    """
}

initial_cluster_for_outliers_removal
    .combine(atlas_directory_for_outliers_removal)
    .set{files_for_clusters_outliers_removal}

process WM_Cluster_Remove_Outliers {
    publishDir "./results/${sid}/FiberClustering"
    memory '5 GB'

    input:
    set sid, file(clusters), file(atlas_directory) from files_for_clusters_outliers_removal

    output:
    set sid, "OutlierRemovedClusters/*" into cleaned_cluster_for_qc, cleaned_cluster_for_hemisphere_assessment

    script:
    String clusters = clusters.join(", ").replace(',', '')
    """
    for i in ${clusters}
    do
        name=\$(basename "\$i")
        wm_cluster_remove_outliers.py \${i}/\${name}_reg ${atlas_directory}/ORG-800FC-100HCP/ ./OutlierRemovedClusters/\${name}
        wm_assess_cluster_location_by_hemisphere.py ./OutlierRemovedClusters/\${name}/\${name}_reg_outlier_removed/ -clusterLocationFile ${atlas_directory}/ORG-800FC-100HCP/cluster_hemisphere_location.txt
    done
    """
}

process WM_Quality_Control_Tractography_For_Clusters_Cleaned {
    publishDir "./results/${sid}/QC"
    memory '5 GB'

    input:
    set sid, file(clusters) from cleaned_cluster_for_qc

    output:
    file "FiberCluster-OutlierRemoved/*"

    when:
    !params.qc_only_anatomical_tracts

    script:
    String clusters = clusters.join(", ").replace(',', '')
    """
    for i in ${clusters}
    do
        name=\$(basename "\$i")
        wm_quality_control_tractography.py \${i}/\${name}_reg_outlier_removed/ ./FiberCluster-OutlierRemoved/\${name}   
    done
    """
}

tract_registration_for_harden_transform
    .join(cleaned_cluster_for_hemisphere_assessment)
    .combine(slicer)
    .set{files_for_wm_harder_transform}


process WM_Harden_Transform {
    publishDir "./results/${sid}/FiberClustering"
    memory '5 GB'

    input:
    set sid, file(tracking), cluster, slicer from files_for_wm_harder_transform

    output:
    set sid, "TransformedClusters/*" into transformed_clusters_for_hemisphere_assessment

    script:
    String tracking = tracking.join(", ").replace(',', '')

    cluster = (cluster instanceof Path) ? cluster : cluster[0]
    """
    echo ${cluster}

    cluster=\$(dirname ${cluster})

    for i in ${tracking}
    do
        name=\$(basename "\$i")
        wm_harden_transform.py -i -t \${i}/\${name}/output_tractography/itk_txform_\${name}.tfm \
            \${cluster}/\${name}/\${name}_reg_outlier_removed/ \
            ./TransformedClusters/\${name}/ \
            ${slicer}
    done
    """
}

process WM_Separate_Clusters_By_Hemisphere {
    publishDir "./results/${sid}/FiberClustering"
    memory '5 GB'

    input:
    set sid, file(clusters) from transformed_clusters_for_hemisphere_assessment

    output:
    set sid, "SeparatedClusters/*" into hemisphere_cluster_for_anatomical_tracts

    script:
    String clusters = clusters.join(", ").replace(',', '')
    """
    for i in ${clusters}
    do
        name=\$(basename "\$i")
        wm_separate_clusters_by_hemisphere.py \${i} ./SeparatedClusters/\${name}
    done
    """
}

hemisphere_cluster_for_anatomical_tracts
    .combine(atlas_directory_for_clusters_to_anatomical_tracts)
    .set{files_for_clusters_to_anatomical_tracts}


process WM_Append_Clusters_To_Anatomical_Tracts {
    publishDir "./results/${sid}/AnatomicalTracts"
    memory '5 GB'

    input:
    set sid, file(clusters), file(atlas_directory) from files_for_clusters_to_anatomical_tracts

    output:
    set sid, "anat/*" into anatomical_tracts_for_qc

    script:
    String clusters = clusters.join(", ").replace(',', '')
    """
    for i in ${clusters}
    do
        name=\$(basename "\$i")
        echo \${name}
        wm_append_clusters_to_anatomical_tracts.py \${i} ${atlas_directory}/ORG-800FC-100HCP/ ./anat/\${name}
    done
    """
}

process WM_Quality_Control_Tractography_For_Anatomical_Tracts {
    publishDir "./results/${sid}/QC"
    memory '5 GB'

    input:
    set sid, file(clusters) from anatomical_tracts_for_qc

    output:
    file "AnatomicalTracts/*"

    script:
    String clusters = clusters.join(", ").replace(',', '')
    """
    for i in ${clusters}
    do
        name=\$(basename "\$i")
        wm_quality_control_tractography.py \${i} ./AnatomicalTracts/\${name}
    done
    """
}