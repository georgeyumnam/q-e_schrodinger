
!
! Copyright (C) 2001-2003 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#include "f_defs.h"
!
!--------------------------------------------------------------------------
SUBROUTINE make_pointlists
  !--------------------------------------------------------------------------
  !
  ! This initialization is needed in order to integrate charge (or
  ! magnetic moment) in a sphere around the atomic positions.
  ! This can be used to simply monitor these quantities during the scf
  ! cycles or in order to calculate constrains on these quantities.
  !
  ! In the input the integration radius r_m can be given, otherwise it is
  ! calculated here. The integration is a sum over all points in real
  ! space with the weight 1, if they are closer than r_m to an atom
  ! and    1 - (distance-r_m)/(0.2*r_m) if r_m<distance<1.2*r_m            
  !

  USE kinds,      ONLY : dp
  USE io_global,  ONLY : stdout
  USE ions_base,  ONLY : nat, tau
  USE cell_base,  ONLY : at, bg
  USE gvect,      ONLY : nr1, nr2, nr3, nrx1, nrx2, nrxx
  USE mp_global,  ONLY : me_pool
  USE pfft,       ONLY : npp

  USE noncollin_module
  !
  IMPLICIT NONE
  !
  INTEGER index0,index,indproc,iat,ir,iat1
  INTEGER i,j,k,i0,j0,k0,ipol,ishift(3)

  REAL(kind=dp) :: posi(3),distance,shift(3),scalprod, distmin
  REAL(kind=dp), ALLOCATABLE :: tau0(:,:)

  IF (.NOT.(noncolin)) RETURN
  WRITE( stdout,*) "  Generating pointlists ..."
  ALLOCATE(tau0(3,nat))

  ! First, the real-space position of every point ir is needed ...

  ! In the parallel case, find the index-offset to account for the planes
  ! treated by other procs

  index0 = 0
#ifdef __PARA
  DO indproc=1,me_pool
     index0 = index0 + nrx1*nrx2*npp(indproc)
  ENDDO

#endif
  ! Bring all the atomic positions on the first unit cell

  tau0=tau
  CALL cryst_to_cart(nat,tau0,bg,-1)
  DO iat=1,nat
     DO ipol=1,3
        tau0(ipol,iat)=tau0(ipol,iat)-NINT(tau0(ipol,iat))
     ENDDO
  ENDDO
  CALL cryst_to_cart(nat,tau0,at,1)

  ! Check the minimum distance between two atoms in the system

  distmin = 1.d0

  DO iat = 1,nat
     DO iat1 = iat,nat

        ! posi is the position of a second atom
        DO i = -1,1
           DO j = -1,1
              DO k = -1,1

                 distance = 0.d0
                 DO ipol = 1,3
                    posi(ipol) = tau0(ipol,iat1) + REAL(i)*at(ipol,1) &
                         &                       +REAL(j)*at(ipol,2) + REAL(k)*at(ipol,3)
                    distance = distance + (posi(ipol)-tau0(ipol,iat)) &
                         &                       **2.
                 ENDDO

                 distance = SQRT(distance)
                 IF ((distance.LT.distmin).AND.(distance.GT.1.d-8)) &
                      &                    distmin = distance

              ENDDO ! k
           ENDDO ! j
        ENDDO ! i

     ENDDO                  ! iat1
  ENDDO                     ! iat

  IF ((distmin.LT.(2.d0*r_m*1.2d0)).OR.(r_m.LT.1.d-8)) THEN
     ! Set the radius r_m to a value a little smaller than the minimum
     ! distance divided by 2*1.2 (so no point in space can belong to more
     ! than one atom)
     r_m = 0.5d0*distmin/1.2d0 * 0.99d0
     WRITE( stdout,*) "    new r_m : ",r_m
  ENDIF


  ! Now, make for every atom a list of points which are in their
  ! integration sphere, as well as a list of weights.
  ! This also works in the parallel case.

  DO iat = 1,nat

     pointnum(iat) = 0

     DO ir=1,nrxx
        index = index0 + ir - 1

        k0 = index/(nrx1*nrx2)
        index = index - (nrx1*nrx2) * k0
        j0 = index / nrx1
        index = index - nrx1*j0
        i0 = index

        DO i = i0-nr1,i0+nr1, nr1
           DO j = j0-nr2, j0+nr2, nr2
              DO k = k0-nr3, k0+nr3, nr3

                 DO ipol=1,3
                    posi(ipol) =  REAL(i)/REAL(nr1) * at(ipol,1) &
                         + REAL(j)/REAL(nr2) * at(ipol,2) &
                         + REAL(k)/REAL(nr3) * at(ipol,3)

                    posi(ipol) = posi(ipol) - tau0(ipol,iat)
                 ENDDO

                 distance = SQRT(posi(1)**2+posi(2)**2+posi(3)**2)


                 IF (distance.LE.r_m) THEN
                    pointnum(iat) = pointnum(iat) + 1
                    factlist(pointnum(iat),iat) = 1.d0
                    pointlist(pointnum(iat),iat) = ir

                 ELSE IF (distance.LE.1.2*r_m) THEN
                    pointnum(iat) = pointnum(iat) + 1
                    factlist(pointnum(iat),iat) = 1.d0 - (distance &
                         -r_m)/(0.2d0*r_m)
                    pointlist(pointnum(iat),iat) = ir

                 ENDIF


              ENDDO         ! k
           ENDDO            ! j
        ENDDO               ! i

     ENDDO                  ! ir


  ENDDO                     ! ipol
  DEALLOCATE(tau0)

END SUBROUTINE make_pointlists

