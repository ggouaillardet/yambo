!
!        Copyright (C) 2000-2015 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
!
! This file is distributed under the terms of the GNU
! General Public License. You can redistribute it and/or
! modify it under the terms of the GNU General Public
! License as published by the Free Software Foundation;
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will
! be useful, but WITHOUT ANY WARRANTY; without even the
! implied warranty of MERCHANTABILITY or FITNESS FOR A
! PARTICULAR PURPOSE.  See the GNU General Public License
! for more details.
!
! You should have received a copy of the GNU General Public
! License along with this program; if not, write to the Free
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston,
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine SET_defaults(INSTR,IND,OD,JS,COM_DIR)
 !
 use drivers
 use pars,       ONLY:SP,schlen
 use units,      ONLY:HA2EV,FS2AUT,AU2VMm1
 use LOGO,       ONLY:ID_logo,ID_logo_stderr
 use X_m,        ONLY:current_iq,self_detect_E_range,half_X_mat_only,eps_2_alpha,&
&                      alpha_dim,use_X_DbGd,X_DbGd_nkpts,Chi_mode,skip_cond_sum_rule,&
&                      eval_alpha,Vnl_commutator_warning,use_shifted_grids_approach,use_g_space_approach,&
&                      q_plus_G_direction,Q_Shift_Order,n_X_descs,Dipole_Energy_treshold,&
&                      X_terminator,X_en_comp,global_gauge,use_covariant_approach,integrating_over_q,&
&                      force_v_g_space_approach,use_real_space_approach,Dipole_approach
 use QP_m,       ONLY:QP_dSc_steps,QP_n_W_freqs,QP_G_Zoom_treshold,&
&                     QP_dSc_test,QP_solver,QP_G_damp,QP_dSc_delta,&
&                     QP_cg_percent,QP_n_states,&
&                     QP_ctl_db,QP_ctl_interp_neigh,SC_E_threshold, &
&                     QP_Sc_steps,QP_G_er,QP_G_dr,SC_band_mixing,&
&                     GWo_SC_done,GWo_iterations,&
&                     COHSEX_use_empties,QP_ctl_E,QP_ctl_Wc,QP_ctl_Wv,QP_ctl_Z,On_Mass_Shell_approx,&
&                     Vnlxc_kind,Vxc_kind,l_extended_output,l_GW_terminator,&
&                     GW_terminator_E
 use functions,  ONLY:bose_E_cut
 use D_lattice,  ONLY:i_space_inv,inv_index,n_atoms_species_max,n_atomic_species,mag_syms,&
&                     input_Tel_is_negative,non_periodic_directions,lattice,Bose_Temp
 use pseudo,     ONLY:pp_n_l_times_proj_max,pp_kbv_dim
 use R_lattice,  ONLY:n_g_shells,ng_closed,bse_scattering,coll_scattering,&
&                     Xk_grid_is_uniform,RIM_id_epsm1_reference,RIM_epsm1,&
&                     RIM_anisotropy,RIM_ng,RIM_n_rand_pts,nqibz,q0_def_norm,&
&                     cutoff_presets,k_map
 use electrons,  ONLY:n_spin,n_sp_pol,n_spinor,BZ_DbGd_nbands,BZ_DbGd_tot_nkpts,&
&                     filled_tresh,l_spin_orbit,n_spin_den,BZ_ASSOCIATED_nkpts,&
&                     eval_magn,E_SOC_nbands
 use parallel_m, ONLY:ncpu,CPU_str_reset
 use com,        ONLY:isec,depth,secnm,previous_secmode,of,opened_of,of_unit,max_open_ofs,&
&                     more_io_path,core_io_path,jobstr,com_path,alt_jobstr,repfile,n_alt_jobstr,&
&                     n_max_jobstr,grid_paths
 use stderr,     ONLY:win_size,tty_size,logfile,set_real_printed_length,&
&                     string_split,log_as_a_file
 use LIVE_t,     ONLY:log_line_to_dump,log_line,nhash,ct
 use wave_func,  ONLY:wf_ng,wf_norm_test,wf_nb_io,wf_nb_io_groups,WF,WF_buffer,WF_buffered_IO
 use FFT_m,      ONLY:fft_dim_loaded,fft_size,fft_dim,fft_multiplier
 use IO_m,       ONLY:io_reset,max_io_units,serial_number,mk_dir,frag_WF
 use BS,         ONLY:BS_n_g_W,BS_eh_en,BS_identifier,BS_q,BS_eh_win,BS_drude_f_eh,&
&                     BS_res_mode,BS_K_dim,BS_cpl_mode,BS_not_const_eh_f,BSK_mode,&
&                     BSS_mode,BSS_n_freqs,BSS_n_descs,BSS_er,BSS_dr,BSE_mode,&
&                     BSS_q0,Haydock_treshold,BS_K_is_ALDA,BSS_uses_DbGd,BSS_damp_reference,&
&                     BSS_Vnl_included,BSS_uses_GreenF,BSS_inversion_mode,BS_anti_res
 use TDDFT,      ONLY:FXC_description,FXC_type,FXC_n_descs,FXC_n_g_corr,&
&                     FXC_per_memstps,FXC_LRC_alpha,FXC_LRC_beta,FXC_SVD_digits,&
&                     FXC_is_causal,TDDFT_mode
 use ACFDT,      ONLY:ACFDT_n_lambda,ACFDT_n_freqs,ACFDT_E_range
#if defined _ELPH 
 use ELPH,       ONLY:ph_modes,elph_nb,gsqF_energy_steps,eval_G_using_KK,&
&                     elph_Ham_bands,elph_Ham_ik,elph_branches,RES_tresh,FAN_deltaE_treshold,DW_deltaE_treshold
#endif
 use memory_m,   ONLY:mem_reset
 use zeros,      ONLY:zero_norm,k_iku_zero,k_rlu_zero,G_iku_zero,zero_dfl
 use xc_functionals,  ONLY:GS_xc_FUNCTIONAL,GS_xc_KIND,GS_exx_FRACTION,GS_exx_SCREENING 
 use interpolate, ONLY:interpls,max_interpls
#if defined _TIMING
 use timing_m,    ONLY:timing_allocate,nclockx
#endif
 use openmp,      ONLY:OPENMP_initialize,OPENMP_update,master_thread
 !
 implicit none
 !
 character(*) :: INSTR,IND,OD,JS,COM_DIR
 !
 ! Work Space 
 !
 integer           :: i1,i2
 character(schlen) :: string(10)
 !
 ! Printed reals format lengths 
 !
 call set_real_printed_length()
 !
 ! CPU structures
 !
 call CPU_str_reset()
 !
 call OPENMP_initialize( )
 call OPENMP_update(master_thread)
 !
 ! Stack Size 
 !
 call remove_stack_limit()
 !
 !
 ! Clocks
 !
#if defined _TIMING
 call timing_allocate(nclockx)
#endif
 !
 ! ZEROs 
 !
 zero_norm =zero_dfl
 k_iku_zero=zero_dfl
 k_rlu_zero=zero_dfl
 G_iku_zero=zero_dfl
 !
 ! PATHS  ...
 !
 core_io_path=IND
 more_io_path=OD
 com_path=COM_DIR
 !
 ! ... created (core only)
 !
 call mk_dir(core_io_path)
 !
 ! ... and Job string
 !
 call string_split(JS,string,",")
 jobstr=string(1)
 alt_jobstr=" "
 do i1=2,n_max_jobstr
   if (len_trim(string(i1))==0) cycle
   alt_jobstr(i1-1)=string(i1)
   n_alt_jobstr=i1-1
 enddo
 !
 ! WFs fragmentation, this is for the interfaces
 !
 frag_WF = (.not.index(INSTR,'nodbfr')>0 .or. index(INSTR,'fragnb')>0)
 !
 ! Logical Setup (Mainly for interfaces and ypp. As far as yambo is concerned this call is done in init.F)
 !
 call SET_logicals()
 !
 ! TTY size 
 !
 call win_size(tty_size)
 call ct(INIT=.TRUE.)
 log_as_a_file=ncpu>1.or.tty_size<0
 !
 !I/O 
 !
 serial_number=0
 !
 !com
 !
 isec=0
 depth=-1
 secnm=' '
 previous_secmode=' '
 of=' '
 opened_of=' '
 of_unit=0
 of_unit(max_open_ofs)=-11
 !
 !LOGO
 !
 ID_logo=-1
 ID_logo_stderr=-1
 !
 !stderr
 !
 repfile=" "
 write (logfile,'(2a)') trim(more_io_path),'/l_stderr'
 !
 !Timing
 !
 log_line_to_dump=.FALSE.
 log_line=' '
 nhash=40
 !
 !functions
 !
 bose_E_cut=0.1_SP
 !
 !D_lattice
 !
 input_Tel_is_negative=.FALSE.
 non_periodic_directions='none'
 lattice='Unknown'
 Bose_Temp=-1./HA2EV
 !
 ! R_lattice
 !
 n_g_shells=0
 nqibz=0
 ng_closed=0
 coll_scattering=.FALSE.
 bse_scattering=.FALSE.
 Xk_grid_is_uniform=.TRUE.
 q0_def_norm=1.E-5_SP
 k_map%g0_idx  =-1
 k_map%q_step  =-1
 k_map%max_kdir= 0
 !
 ! RIM
 !
 RIM_id_epsm1_reference=0
 RIM_epsm1=0.
 RIM_anisotropy=0._SP
 RIM_ng=0
 RIM_n_rand_pts=0
 !
 ! CUTOFF
 !
 call cutoff_presets()
 !
 ! D_lattice 
 !
 n_atoms_species_max=0
 n_atomic_species=0
 i_space_inv=-1
 inv_index=0
 mag_syms=.FALSE.
 !
 ! Pseudo
 !
 pp_n_l_times_proj_max=0
 pp_kbv_dim=0
 !
 !drivers
 !
 list_dbs=.FALSE.
 infile_editing=.FALSE.
 l_setup=.FALSE.
 l_rim=.FALSE.
 l_col_cut=.FALSE.
 l_optics=.FALSE.
 l_HF_and_locXC=.FALSE.
 l_em1d=.FALSE.
 l_em1s=.FALSE.
 l_ppa=.FALSE.
 l_cohsex=.FALSE.
 l_gw0=.FALSE.
 l_life=.FALSE.
 l_chi=.FALSE.
 l_bse=.FALSE.
 l_bsk=.FALSE.
 l_bss=.FALSE.
 l_rpa_IP=.FALSE.
 l_td_hartree=.FALSE.
 l_tddft=.FALSE.
 l_alda_fxc=.FALSE.
 l_lrc_fxc=.FALSE.
 l_bs_fxc=.FALSE.
 l_td_hf=.FALSE.
 l_W_eh=.FALSE.
 l_W_eh_diag=.FALSE.
 l_W_eh_cpl=.FALSE.
 l_acfdt=.FALSE.
 l_elel_corr=.FALSE.
 l_elph_corr=.FALSE.
 l_elel_scatt=.FALSE.
 l_elph_scatt=.FALSE.
 !
 l_rt_carriers_in_use=.FALSE.
 l_sc_run=.FALSE.
 l_sc_ip=.FALSE.
 l_sc_hf=.FALSE.
 l_sc_hartree=.FALSE.
 l_sc_cohsex=.FALSE.
 l_sc_exx=.FALSE.
 l_sc_is_libDFT=.FALSE.
 l_sc_magnetic=.FALSE.
 l_eval_collisions=.FALSE.
 l_elph_Hamiltonian=.FALSE.
 !
 !electrons
 !
 n_spin=1
 n_sp_pol=1
 n_spinor=1
 n_spin_den=1
 l_spin_orbit       = .FALSE.
 BZ_DbGd_nbands=0
 BZ_DbGd_tot_nkpts=0
 BZ_ASSOCIATED_nkpts=0
 E_SOC_nbands=0
 filled_tresh=0.00001
 !
 ! Magnetization
 !
 eval_magn=.FALSE.
 !
 !memory
 !
 call mem_reset()
 !
 !wave_func
 !
 WF%b=0
 WF%k=0
 WF%space=' '
 WF_buffer%b=0
 WF_buffer%k=0
 WF_buffer%space=' '
 WF_buffered_IO=.FALSE.
 wf_ng=0
 wf_norm_test=.TRUE.
 wf_nb_io=0
 wf_nb_io_groups=1
 !
 !FFT
 !
 fft_dim_loaded=0
 fft_size=0
 fft_dim=0
 fft_multiplier=(/1,1,1/)
 !
 ! Interpolation
 !
 interpls(1:max_interpls)%ndim=0
 !
 do i1=1,max_io_units
   call io_reset(i1)
 enddo
 !
 !X
 !
 Chi_mode=' '
 current_iq=0
 X_DbGd_nkpts=0
 self_detect_E_range=.FALSE.
 half_X_mat_only=.FALSE.
 Dipole_Energy_treshold=1.E-5_SP/HA2EV
 Dipole_approach="G-space v"
 use_shifted_grids_approach = .FALSE.
 use_covariant_approach     = .FALSE.
 use_real_space_approach    = .FALSE.
 use_g_space_approach       = .TRUE.
 force_v_g_space_approach   = .FALSE.
 use_X_DbGd=.FALSE.
 eps_2_alpha=1._SP
 alpha_dim='adim'
 global_gauge='length'
 grid_paths=' '
 skip_cond_sum_rule=.FALSE.
 eval_alpha=.FALSE.
 Vnl_commutator_warning=.FALSE.
 integrating_over_q=.FALSE.
 q_plus_G_direction=0._SP
 Q_Shift_Order=1
 n_X_descs=0
 X_terminator=.FALSE.
 X_en_comp=2._SP
 !
 !QPm
 !
 QP_n_states=0
 QP_dSc_steps=2
 QP_G_Zoom_treshold=0._SP
 QP_Sc_steps=100
 QP_n_W_freqs=100
 QP_dSc_test=.FALSE.
 QP_solver=' '
 QP_G_damp=0.1/HA2EV
 QP_dSc_delta=0.1/HA2EV
 QP_G_er=(/-10._SP/HA2EV,10._SP/HA2EV/)
 QP_G_dr=0.1/HA2EV
 QP_cg_percent=100._SP
 GWo_iterations=0
 GWo_SC_done=.FALSE.
 COHSEX_use_empties=.FALSE.
 On_Mass_Shell_approx=.FALSE.
 SC_E_threshold=0.01/HA2EV
 SC_band_mixing=100._SP
 Vnlxc_kind='HF'
 Vxc_kind='LDA'
 l_extended_output=.FALSE.
 l_GW_terminator=.FALSE.
 GW_terminator_E=1.5_SP
 !
 ! QP_ctl control
 !
 QP_ctl_db="none"
 QP_ctl_interp_neigh=1
 forall (i1=1:3,i2=1:2) QP_ctl_E(i1,:,i2)=(/0.,1.,1./)
 forall (i1=1:3,i2=1:2) QP_ctl_Wc(i1,:,i2)=0._SP
 forall (i1=1:3,i2=1:2) QP_ctl_Wv(i1,:,i2)=0._SP
 forall (i1=1:3,i2=1:2) QP_ctl_Z(i1,i2)=(1._SP,0._SP)
 !
 !
 ! BS/BSS
 !
 BS_n_g_W=1
 BS_eh_en=(/-1._SP,-1._SP/)/HA2EV
 BS_drude_f_eh=0._SP
 BS_identifier=0
 BS_q=1
 BS_eh_win=100._SP
 BS_res_mode='xc'
 BS_cpl_mode='none'
 BSE_mode='causal'
 BSK_mode=' '
 TDDFT_mode=' '
 BS_anti_res=.FALSE.
 BS_K_dim=0
 BSS_mode=' '
 BSS_inversion_mode='pf'
 BSS_n_freqs=100
 BSS_n_descs=0
 BSS_er=(/0._SP,10._SP/)/HA2EV
 BSS_dr=0.1_SP/HA2EV
 BSS_q0=(/1._SP,0._SP,0._SP/)
 BSS_uses_DbGd=.FALSE.
 BSS_damp_reference=0._SP
 BS_K_is_ALDA=.FALSE.
 BS_not_const_eh_f=.FALSE.
 Haydock_treshold=-0.02_SP
 BSS_Vnl_included=.FALSE.
 BSS_uses_GreenF=.FALSE.
 !
 ! TDDFT
 !
 FXC_description=""
 FXC_type='rpa'
 FXC_n_descs=0
 FXC_n_g_corr=1
 FXC_per_memstps=100._SP
 FXC_LRC_alpha=0._SP
 FXC_LRC_beta=0._SP
 FXC_SVD_digits=0
 FXC_is_causal=.FALSE.
 !
 ! ACFDT
 !
 ACFDT_n_lambda=1
 ACFDT_n_freqs=10
 ACFDT_E_range=(/100.,1000./)/HA2EV
 !
 ! xc_functionals  
 !
 GS_xc_FUNCTIONAL=-1             ! unknow 
 GS_xc_KIND=-1                   ! unknow 
 GS_exx_FRACTION=0.0             ! no EXX part  
 GS_exx_SCREENING=0.0            ! no screening
 !
#if defined _ELPH 
 !
 ! ELPH
 !
 ph_modes=0
 elph_nb=0
 elph_branches=0
 gsqF_energy_steps=2
 eval_G_using_KK=.FALSE.
 elph_Ham_bands=0
 elph_Ham_ik=1
 RES_tresh=0.01_SP
 DW_deltaE_treshold=1.E-6_SP/HA2EV
 FAN_deltaE_treshold=1.E-6_SP/HA2EV
#endif
 !
 !
 !
end subroutine