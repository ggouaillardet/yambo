!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): CH
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
 subroutine reels_ypp
 !--------------------------
 ! RAS in 3 layer model:
 ! \frac{\delta R}{R} = \frac{4\omega\d_surf}{c} \times
 !                      \Im \frac{ \epsilon^s_x - \epsilon^s_y}{\epsilon_b - 1}
 !
 ! The polarizability is:
 ! \epsilon = \frac{4 \pi}{\Omega} \alpha + 1
 ! and for a surface, \Omega = d_z (the cell height)
 ! Hence if polarizability is read, the data should be scaled by
 !                \frac{4 \pi}{d_z} * d_surf, and add  + 1
 !
 ! Input can be epsilon over cell, or alpha over cell.
 ! User needs to distinguish the two cases, and give d_cell.
 ! In case epsilon: d_surf = d_cell is passed to RAS_spectrum, with
 !   no scaling
 ! In case alpha  : d_surf = d_cell, and alpha is scaled by the
 !   above factor (the + 1 cancels in all difference spectra)
 !
 ! Input of d_cell is not strictly necessary for the RAS from alpha, but will 
 ! give incorrect eps_x-eps_y in the output file.
 !
 use pars,                ONLY:DP, lchlen,schlen, PI
 use units,               ONLY:HA2EV
 use com,                 ONLY:msg, error
 use IO_m,                ONLY:io_control,OP_WR_CL,NONE,OP_APP_WR_CL,&
&                              OP_RD_CL,VERIFY
 use LIVE_t,              ONLY:live_timing
 use YPP
 use bulkeps,             ONLY : lbulkerr, GetBulkEps
 use eels_kinematics
 use surface_geometry
 use eels_detector
 use model_loss_function
 use convolute
 implicit none
 !
 !Work Space
 !
 integer, parameter         :: maxlines = 10001
 complex(SP)                :: f(maxlines)
 real(SP)                   :: freq(maxlines) , sscale
 integer            ::iq , i,nw, nwy, pol_type, npol
 logical                    :: lfail = .false., do_ras = .true., lsurferr = .false.
 character(lchlen)          :: errmsg
 complex(SP), allocatable   :: eps_b(:),eps_i(:,:),surf_i(:,:),eps_g(:,:)
 real(SP),    allocatable   :: hw(:), lossf(:,:)
real(SP)                       :: qpard(2), q0v(3,3)

 call section('*',"== REELS postprocessor ==")
 !
 ! Some initializations
 !
 npol  = 3

 call msg('nrs','Import eps X/Y/Z files')
 !
 call read_spectral_data(xdata,datatype,nw,lfail)
 allocate(eps_i(nw,3),hw(nw),eps_b(nw),surf_i(nw,3),lossf(nw,3), eps_g(nw,3))
 eps_i(1:nw,1) = f(1:nw)
 hw(1:nw) = freq(1:nw)/HA2EV + sshift ! shift is internally converted
 call read_spectral_data(ydata,datatype,nwy,lfail)
 if(nwy.ne.nw) call error('X/Y datafiles have inconsistent data')
 eps_i(1:nw,2) = f(1:nw)
 call read_spectral_data(zdata,datatype,nwy,lfail)
 if(nwy.ne.nw) call error('X/Z datafiles have inconsistent data')
 eps_i(1:nw,3) = f(1:nw)

 lbulkerr = .false. ; lsurferr = .false.
 call msg('nrs','Import bulk')
 call GetBulkEps(hw, nw, eps_b, errmsg)
 call msg('nrs',trim(errmsg))
 if(lbulkerr) call error(' Stopping')

 call section('=','Write eps cell for plotting:')
 call write_eps_tensor( q0v, eps_i, hw, nw, npol, 'cell' )

 ! 
 ! Write the broadened eps cell also
 ! 
 eps_g = eps_i
 call broaden_tensor
 call write_eps_tensor( q0v, eps_g, hw, nw, npol, 'cell-broad' )
 !
 ! Setup the REELS geometry
 !
 call section('+','Surface geometry and spectral analysis')
 call setup_surface_geometry( lfail )
 call print_surface_geometry

 call section('=','REELS setup')
 call setup_eels_kin( lfail )
 if(lfail) call error('in setup_eels_kin')
 call print_eels_kin
 call setup_eels_det( lfail)
 if(lfail) call error('in setup_eels_det')
 call print_eels_det
 call check_eels_det( lfail )
 if(lfail) call error('in print/check_eels_det')
 call print_eels_form
 call print_eels_geometry
 q0v(:,1) = q0x ; q0v(:,2) = q0y ; q0v(:,3) = norm

 call section('=','Slab symmetries: ')
 call get_slab_symmetry( .false. )

 call section('=','Surface dielectric function')
 call extract_eps_surf(surf_i, eps_i, npol, eps_b, nw, lbulkerr, lsurferr)
 if(lsurferr) stop ' Stopping'
 if(.not.lsurferr) call write_eps_tensor( q0v, surf_i, hw, nw, npol, 'surf' )

 call section('=','REELS')

 if(.not.lbulkerr) call CalcREELS(lossf, hw, surf_i, eps_b, nw, qpard)
 call write_reelsdiff(lossf, hw, nw )

 contains
  
   subroutine read_spectral_data(filename,col,nw,lfail)
     use com,              ONLY : file_exists
     implicit none
     character*(*), intent(in) :: filename
     logical, intent(inout)    :: lfail
     integer, intent(out)      :: nw
     character(5), intent(in)  :: col
     character(lchlen)         :: cline
     integer, parameter        :: un = 60
     real(SP)                  :: rimag,rreal,rdum
     
     if(.not.(file_exists(trim(filename))) ) then
       errmsg='Unable to find file '//trim(filename)
       lfail = .true.
       return
     endif

     open(unit=un,file=trim(filename),err=998)
     nw = 0
     do while(.true.)
       read(un,*,end=99) cline
       if(index(cline,"#") > 0) cycle
       backspace(un)
       nw = nw + 1
       if(nw.gt.maxlines) goto 1000
       if( index(col,"23").eq.4 ) then
         read(un,*,err=999) freq(nw),rimag,rreal
       else if( index(col,"45").eq.4 ) then
         read(un,*,err=999) freq(nw),rdum,rdum,rimag,rreal
       else
         errmsg='Unable read data with datatype: '//trim(datatype)
         lfail = .true.
         return
       endif
       f(nw) = cmplx(rreal,rimag)
     enddo
99   continue
     return

998  continue
     close(un)
     errmsg='Problem opening for reading the file '//trim(filename)
     lfail = .true.
     return

999  continue
     errmsg='Strange problem reading the file '//trim(filename)
     lfail = .true.
     close(un)
     return

1000 continue
     errmsg='File too large! '//trim(filename)
     lfail = .true.
     close(un)
     return
     
   end subroutine read_spectral_data
  
   subroutine broaden_tensor
     real(SP),    allocatable   :: tmpi(:),tmpr(:)
     integer                    :: i
     allocate( tmpi(nw), tmpr(nw) )
     do i = 1,3
       tmpi = aimag(eps_g(:,i))
       tmpr =  real(eps_g(:,i))
       call convolute_gaussian(tmpi, hw, nw)
       call convolute_gaussian(tmpr, hw, nw)
       eps_g(:,i) = cmplx(tmpr,tmpi)
     enddo

     deallocate(tmpi, tmpr)
   end subroutine broaden_tensor
   
 end subroutine reels_ypp
