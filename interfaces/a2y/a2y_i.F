!
! Copyright (C) 2000-2008 A. Marini and the YAMBO team 
!              http://www.yambo-code.org
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
integer function a2y_i(instr,lnstr,inf,iinf,ind,iind,od,iod,&
&                      com_dir,icd,js,ijs,np,pid)
 !
 use pars,                ONLY:SP,lchlen
 use LOGO,                ONLY:pickup_a_random
 use com,                 ONLY:msg,write_to_report,more_io_path
 use par_proc_m,          ONLY:ncpu,myid,p_finalize
 use electrons,           ONLY:levels,E_reset,n_bands,n_spin
 use D_lattice,           ONLY:n_atoms_max
 use R_lattice,           ONLY:bz_samp,bz_samp_reset,nkibz
 use timing,              ONLY:live_timing_is_on
 use wave_func,           ONLY:wf_ncx,ioWF,wf_nb_io_groups,wf_nb_io
 use IO_m,                ONLY:io_control,OP_WR_CL,NONE,OP_APP_WR_CL,serial_number
 use mod_com2y,           ONLY:interface_presets,force_noWFs
 use mod_wf2y,            ONLY:wf_splitter
 !
 implicit none
 type(levels)                 :: en 
 type(bz_samp)                :: k 
 integer,          intent(in) :: lnstr,iind,iod,ijs,np,pid,icd
 integer,          intent(in) :: iinf
 character(lnstr), intent(in) :: instr
 character(iinf),  intent(in) :: inf
 character(iind),  intent(in) :: ind
 character(iod),   intent(in) :: od
 character(ijs),   intent(in) :: js
 character(icd),   intent(in) :: com_dir   
 !
 character(lchlen) :: KSS_file_name
 integer           :: ID,io_err,ioPP_err,ik,icycle,ib_grp
 integer,     external :: a2y_KSS_file_name,ioDB1,ioKB_PP
 real(SP), allocatable :: wf_disk(:,:,:,:)
 !
 ! Presets
 !
 a2y_i =0
 ncpu  =np
 myid  =pid
 call std_presets(instr,ind,od,'','')
 call interface_presets(instr)
 call bz_samp_reset(k)
 call E_reset(en) 
 !
 ! S/N
 !
 serial_number=pickup_a_random(10000.)
 !
 ! Switch off report file support
 !
 write_to_report=.FALSE.
 ! live_timing_is_on=.FALSE.
 !
 call section('*','A(binit) 2 Y(ambo)')
 !
 call msg('s','Checking input file ...')
 !
 if ( a2y_KSS_file_name(inf,KSS_file_name) < 0 ) then
   call msg('ln','failed')
   call p_finalize
   return
 endif
 call msg('l',trim(KSS_file_name))
 !
 call msg('s','DBs path set to :',trim(more_io_path))
 !
 call a2y_db1(en,k,trim(KSS_file_name))
 !
 call msg('s','== DB1 ...')
 !
 call io_control(ACTION=OP_WR_CL,COM=NONE,SEC=(/1,2/),ID=ID)
 io_err=ioDB1(en,k,ID)
 !
 if (force_noWFs) then
   call msg('ln','done ==')
   call p_finalize
   return
 else
   call msg('l','done ==')
 endif
 !
 call wf_splitter()
 !
 call msg('s','== DB2 + nlPP ...')
 !
 allocate(wf_disk(2,wf_nb_io,wf_ncx,n_spin))
 do ik=1,nkibz
   !
   do ib_grp=1,wf_nb_io_groups
     !
     call a2y_wf(wf_disk,ik,ib_grp,trim(KSS_file_name))
     !
     if (n_atoms_max>0.and.ib_grp==1) then
       if (ik==1) call io_control(ACTION=OP_WR_CL,COM=NONE,SEC=(/1,2/),ID=ID)
       if (ik> 1) call io_control(ACTION=OP_APP_WR_CL,COM=NONE,SEC=(/ik+1/),ID=ID)
       io_err=ioKB_PP(ID)
     endif
     !
     if (ik==1.and.ib_grp==1) call io_control(ACTION=OP_WR_CL,COM=NONE,SEC=(/1,2,1/),ID=ID)
     if (ik> 1.or. ib_grp> 1) call io_control(ACTION=OP_APP_WR_CL,COM=NONE,SEC=(/ik+1,ib_grp/),ID=ID)
     io_err=ioWF(ID,wf=wf_disk)
     !
   enddo
   !
 enddo
 deallocate(wf_disk)
 !
 call msg('ln','done ==')
 !
 call p_finalize
 !
end function